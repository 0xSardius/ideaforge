// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import "@chainlink/contracts/src/v0.8/functions/v1_3_0/FunctionsClient.sol";
import "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract IdeaForge is ERC20, Ownable, ReentrancyGuard, FunctionsClient, AutomationCompatibleInterface {
    using FunctionsRequest for FunctionsRequest.Request;

    // Structs
    struct Idea {
        string content;
        address creator;
        uint256 timestamp;
        uint256 aiScore;
        uint256 communityVotes;
        string category;
        bool isPublic;
        bool isAnalyzed;
    }

    struct User {
        uint256 currentStreak;
        uint256 longestStreak;
        uint256 totalIdeas;
        uint256 tokensEarned;
        uint256 lastSubmission;
        bool isPremium;
    }

    // State variables
    mapping(address => User) public users;
    mapping(uint256 => Idea) public ideas;
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    mapping(bytes32 => uint256[]) public pendingAnalysis; // requestId => ideaIds

    uint256 public ideaCounter;
    uint256 public constant DAILY_REWARD = 10 * 10 ** 18; // 10 IDEA tokens
    uint256 public constant IDEAS_PER_DAY = 10;

    // Chainlink Functions
    bytes32 public donId;
    uint64 public subscriptionId;
    uint32 public gasLimit = 300000;
    string public aiAnalysisSource;

    // Events
    event IdeasSubmitted(address indexed user, uint256[] ideaIds);
    event AIAnalysisRequested(bytes32 indexed requestId, uint256[] ideaIds);
    event AIScoreUpdated(uint256 indexed ideaId, uint256 score, string category);
    event TokensRewarded(address indexed user, uint256 amount);
    event IdeaShared(uint256 indexed ideaId, address indexed creator);

    constructor(address router, bytes32 _donId, uint64 _subscriptionId)
        ERC20("IdeaForge Token", "IDEA")
        Ownable(msg.sender)
        FunctionsClient(router)
    {
        donId = _donId;
        subscriptionId = _subscriptionId;
    }

    // Core Functions
    function submitDailyIdeas(string[] calldata _ideas) external {
        require(_ideas.length == IDEAS_PER_DAY, "Must submit exactly 10 ideas");
        require(!hasSubmittedToday(msg.sender), "Already submitted today");

        uint256[] memory newIdeaIds = new uint256[](IDEAS_PER_DAY);

        for (uint256 i = 0; i < IDEAS_PER_DAY; i++) {
            require(bytes(_ideas[i]).length > 0 && bytes(_ideas[i]).length <= 200, "Invalid idea length");

            ideaCounter++;
            ideas[ideaCounter] = Idea({
                content: _ideas[i],
                creator: msg.sender,
                timestamp: block.timestamp,
                aiScore: 0,
                communityVotes: 0,
                category: "",
                isPublic: true,
                isAnalyzed: false
            });

            newIdeaIds[i] = ideaCounter;
        }

        // Update user stats
        users[msg.sender].totalIdeas += IDEAS_PER_DAY;
        _updateStreak(msg.sender);

        // Request AI analysis
        _requestAIAnalysis(newIdeaIds);

        emit IdeasSubmitted(msg.sender, newIdeaIds);
    }

    function _requestAIAnalysis(uint256[] memory ideaIds) internal {
        string[] memory ideaContents = new string[](ideaIds.length);
        for (uint256 i = 0; i < ideaIds.length; i++) {
            ideaContents[i] = ideas[ideaIds[i]].content;
        }

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(aiAnalysisSource);
        req.setArgs(ideaContents);

        bytes32 requestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donId);

        pendingAnalysis[requestId] = ideaIds;
        emit AIAnalysisRequested(requestId, ideaIds);
    }

    // Chainlink Functions callback
    function _fulfillRequest(bytes32 requestId, bytes memory response, bytes memory) internal override {
        uint256[] memory ideaIds = pendingAnalysis[requestId];
        require(ideaIds.length > 0, "Invalid request ID");

        // Parse AI response (expecting JSON with scores and categories)
        // For now, we'll implement a simple parsing mechanism
        _processAIResponse(ideaIds, response);

        delete pendingAnalysis[requestId];
    }

    function _processAIResponse(uint256[] memory ideaIds, bytes memory response) internal {
        // TODO: Implement proper JSON parsing
        // For now, assign random scores for testing
        for (uint256 i = 0; i < ideaIds.length; i++) {
            uint256 score = 50 + (uint256(keccak256(abi.encode(ideaIds[i], block.timestamp))) % 50);
            ideas[ideaIds[i]].aiScore = score;
            ideas[ideaIds[i]].category = "General";
            ideas[ideaIds[i]].isAnalyzed = true;

            emit AIScoreUpdated(ideaIds[i], score, "General");
        }

        // Reward user for completion
        address creator = ideas[ideaIds[0]].creator;
        _mint(creator, DAILY_REWARD);
        users[creator].tokensEarned += DAILY_REWARD;

        emit TokensRewarded(creator, DAILY_REWARD);
    }

    // Utility functions
    function hasSubmittedToday(address user) public view returns (bool) {
        return (block.timestamp - users[user].lastSubmission) < 1 days;
    }

    function _updateStreak(address user) internal {
        uint256 daysSinceLastSubmission = (block.timestamp - users[user].lastSubmission) / 1 days;

        if (daysSinceLastSubmission == 1) {
            // Consecutive day
            users[user].currentStreak++;
        } else if (daysSinceLastSubmission > 1) {
            // Streak broken
            users[user].currentStreak = 1;
        }
        // If same day, no change to streak

        if (users[user].currentStreak > users[user].longestStreak) {
            users[user].longestStreak = users[user].currentStreak;
        }

        users[user].lastSubmission = block.timestamp;
    }

    // Chainlink Automation
    function checkUpkeep(bytes calldata) external pure override returns (bool upkeepNeeded, bytes memory) {
        // TODO: Implement daily maintenance checks
        upkeepNeeded = false;
    }

    function performUpkeep(bytes calldata) external override {
        // TODO: Implement daily maintenance tasks
    }

    // Admin functions
    function setAISource(string memory _source) external onlyOwner {
        aiAnalysisSource = _source;
    }

    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        subscriptionId = _subscriptionId;
    }
}
