// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Gomoku {
    uint256 public gameCount; // 遊戲數量計數
    address public tokenAddress; // 賭注代幣位址
    address public owner; // 合約擁有者地址
    bool public stopped = false; // 緊急停止開關
    mapping(uint256 => Game) public games; // 透過遊戲 ID 映射到遊戲

    enum Stone {
        Empty,
        Black,
        White
    }

    event GameCreated(uint256 gameId); // 創建遊戲事件
    event PlayerJoined(uint256 gameId, address player); // 玩家加入遊戲事件
    event MoveMade(uint256 gameId, uint8 x, uint8 y, Stone thisColor);
    event GameEnded(uint256 gameId, address winner); // 遊戲結束事件
    event RefundClaimed(uint256 gameId, address player1, address player2, uint256 amount); // 賭注退款事件

    struct Game {
        address black; // 黑棋玩家位址
        address white; // 白棋玩家位址
        uint256 stake; // 賭注數量
        address winner; // 勝利者位址
        Stone[15][15] board; // 棋盤
        bool turn; // 誰的回合：true 表示黑棋先手
        bool active; // 棋局是否進行中
        bool frozen; // 棋盤是否凍結，賭注清算完畢則凍結
        address creator; // 遊戲創建者
        address player1; // 參加者1
        address player2; // 參加者2
        bool waitingForPlayerJoin; // 是否等待玩家加入
    }

    constructor() {
        tokenAddress = address(0); // GomokuCoin (GMC)
        owner = msg.sender;
    }

    // 修飾符：只允許擁有者調用
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // 修飾符：在緊急停止時阻止操作
    modifier stopInEmergency() {
        require(!stopped, "Contract is currently stopped");
        _;
    }

    // 修飾符：遊戲是否等待玩家加入
    modifier waitingForPlayerJoin(uint256 _gameId) {
        require(games[_gameId].waitingForPlayerJoin, "Game is not waiting for players");
        _;
    }

    // 修飾詞：遊戲進行中
    modifier gameActive(uint256 _gameId) {
        require(games[_gameId].active, "Game is not active"); // 檢查遊戲是否進行中
        _;
    }

    // 修飾詞：遊戲未凍結
    modifier gameNotFrozen(uint256 _gameId) {
        require(!games[_gameId].frozen, "Game is frozen"); // 檢查遊戲是否已凍結
        _;
    }

    // 創建新棋局的函式，初始化賭注並等待對手
    function createGame(uint256 _stake) public stopInEmergency returns (uint256) {
        Stone[15][15] memory initialBoard; // 初始化棋盤
        games[gameCount] = Game({
            black: address(0),
            white: address(0),
            stake: _stake,
            winner: address(0),
            creator: msg.sender,
            player1: address(0),
            player2: address(0),
            board: initialBoard,
            turn: true,
            active: false,
            frozen: false,
            waitingForPlayerJoin: true
        });
        gameCount++; // 遊戲計數增加
        emit GameCreated(gameCount - 1);
        return gameCount - 1; // 返回新遊戲的ID
    }

    // 玩家加入遊戲
    function joinGame(uint256 _gameId) public stopInEmergency waitingForPlayerJoin(_gameId) gameNotFrozen(_gameId) {
        Game storage game = games[_gameId]; // 獲取遊戲狀態
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), game.stake), "Transfer failed"); // 放入賭注

        if (game.player1 == address(0)) {
            game.player1 = msg.sender; // 設定第一個參加者
        } else {
            game.player2 = msg.sender; // 設定第二個參加者
            // 隨機分配黑白棋方
            bool isBlack = (block.timestamp % 2 == 0);
            if (isBlack) {
                game.black = game.player1;
                game.white = game.player2;
            } else {
                game.black = game.player2;
                game.white = game.player1;
            }
            game.active = true; // 啟動遊戲
            game.waitingForPlayerJoin = false; // 結束等待參加者
        }
        emit PlayerJoined(_gameId, msg.sender);
    }

    // 下棋的函式
    function makeMove(uint256 _gameId, uint8 x, uint8 y)
        public
        stopInEmergency
        gameActive(_gameId)
        gameNotFrozen(_gameId)
    {
        Game storage game = games[_gameId]; // 獲取遊戲狀態
        require(game.board[x][y] == Stone.Empty, "This position is already occupied"); // 檢查位置是否已有棋子
        require(
            (game.turn && msg.sender == game.black) || (!game.turn && msg.sender == game.white),
            "Not your turn" // 檢查是否輪到該玩家
        );

        // 放置棋子
        game.board[x][y] = game.turn ? Stone.Black : Stone.White; // 放置棋子
        emit MoveMade(_gameId, x, y, game.turn ? Stone.Black : Stone.White); // 發送下棋事件

        game.turn = !game.turn; // 更換回合

        // 檢查是否有人贏得遊戲
        if (checkWinner(_gameId, x, y)) {
            game.winner = msg.sender;
            payoutStakes(_gameId); // 處理賭注轉移
        }
    }

    // 投降的函式
    function surrender(uint256 _gameId) public stopInEmergency gameActive(_gameId) gameNotFrozen(_gameId) {
        Game storage game = games[_gameId]; // 獲取遊戲狀態
        require(msg.sender == game.black || msg.sender == game.white, "You are not a player in this game");

        game.winner = msg.sender == game.black ? game.white : game.black; // 設定勝者
        payoutStakes(_gameId); // 處理賭注轉移
    }

    // 建立當緊急停止後 所有放入賭注的人 都可以自由 claim 自己賭注的能力
    // 給予 game id 之後未被凍結的遊戲 將會平分資金給雙方 並且將遊戲凍結
    function claimRefund(uint256 _gameId) public {
        Game storage game = games[_gameId];
        require(stopped, "Contract is not stopped"); // 檢查是否緊急停止了合約
        require(game.active && !game.frozen, "Game is not active or already frozen"); // 檢查遊戲是否仍在進行中且未被凍結
        require(game.stake > 0, "No stakes to claim"); // 檢查是否有賭注可領取

        // 將賭注平分給雙方
        uint256 amountToRefund = game.stake / 2;
        address player1 = game.player1;
        address player2 = game.player2;
        game.stake = 0; // 重置賭注為 0
        game.frozen = true; // 凍結遊戲
        game.active = false; // 標記遊戲為非進行中

        // 轉移賭注給玩家1
        if (player1 != address(0)) {
            require(IERC20(tokenAddress).transfer(player1, amountToRefund), "Transfer to player1 failed");
        }

        // 轉移賭注給玩家2
        if (player2 != address(0)) {
            require(IERC20(tokenAddress).transfer(player2, amountToRefund), "Transfer to player2 failed");
        }

        emit RefundClaimed(_gameId, player1, player2, amountToRefund);
    }

    // 緊急停止所有遊戲的函式（僅限擁有者）
    function emergencyStop() public onlyOwner {
        stopped = true; // 激活緊急停止開關
    }

    // 重啟合約的函式（僅限擁有者）
    function resume() public onlyOwner {
        stopped = false; // 解除緊急停止狀態
    }

    // 結束遊戲並處理賭注
    function payoutStakes(uint256 _gameId) internal stopInEmergency gameActive(_gameId) gameNotFrozen(_gameId) {
        Game storage game = games[_gameId]; // 從遊戲映射中獲取指定 ID 的遊戲狀態
        require(game.winner != address(0), "No winner, unable to settle stakes"); // 確保已經有勝利者，否則無法進行結算

        game.active = false; // 將遊戲狀態標記為非進行中
        bool sent = IERC20(tokenAddress).transfer(game.winner, game.stake); // 將賭注金額從合約轉至勝利者地址
        require(sent, "Stake transfer failed"); // 確認賭注轉移成功，否則拋出錯誤

        game.stake = 0; // 將賭注金額重設為 0，以防萬一
        game.frozen = true; // 將棋盤凍結，避免進一步操作
        emit GameEnded(_gameId, games[_gameId].winner); // 發送遊戲結束事件
    }

    // 檢查是否有人贏得遊戲的函式
    function checkWinner(uint256 _gameId, uint8 x, uint8 y) internal view returns (bool) {
        Stone[15][15] storage board = games[_gameId].board;
        Stone player = board[x][y];
        require(player != Stone.Empty, "No stone in the given position"); // 檢查該位置是否有棋子

        // 勝利需要的連續棋子數量
        uint8 winCondition = 5;

        // 檢查水平方向
        if (countStones(board, x, y, 1, 0) + countStones(board, x, y, -1, 0) + 1 >= winCondition) {
            return true;
        }

        // 檢查垂直方向
        if (countStones(board, x, y, 0, 1) + countStones(board, x, y, 0, -1) + 1 >= winCondition) {
            return true;
        }

        // 檢查正對角線方向
        if (countStones(board, x, y, 1, 1) + countStones(board, x, y, -1, -1) + 1 >= winCondition) {
            return true;
        }

        // 檢查反對角線方向
        if (countStones(board, x, y, 1, -1) + countStones(board, x, y, -1, 1) + 1 >= winCondition) {
            return true;
        }

        return false;
    }

    // 輔助函式，用於計算從一個位置開始沿特定方向的連續同色棋子數量
    function countStones(Stone[15][15] storage board, uint8 startX, uint8 startY, int8 dirX, int8 dirY)
        internal
        view
        returns (uint8 count)
    {
        // 下一個位置
        uint8 posX = startX + uint8(int8(dirX));
        uint8 posY = startY + uint8(int8(dirY));

        // 判斷是否同色並計數
        while (posX < 15 && posY < 15 && posX >= 0 && posY >= 0 && board[posX][posY] == board[startX][startY]) {
            count++;
            posX += uint8(int8(dirX));
            posY += uint8(int8(dirY));
        }
        return count;
    }
}
