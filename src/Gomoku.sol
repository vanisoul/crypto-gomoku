// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Gomoku {
    uint256 public gameCount; // 遊戲數量計數
    address public tokenAddress; // 代幣位址

    struct Game {
        address black; // 黑棋玩家位址
        address white; // 白棋玩家位址
        uint256 stake; // 賭注數量
        address winner; // 勝利者位址
        uint256[15][15] board; // 棋盤：0 表示無棋子，1 表示黑棋，2 表示白棋
        bool turn; // 誰的回合：true 表示黑棋先手
        bool active; // 棋局是否進行中
        bool waitingForOpponent; // 是否在等待對手加入
    }

    mapping(uint256 => Game) public games; // 透過遊戲 ID 映射到遊戲

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress; // 初始化代幣位址
    }

    // 更改代幣位址的函式
    function setTokenAddress(address _newAddress) public {
        // 此處可以加入只有擁有者(owner)可以更改的限制
        tokenAddress = _newAddress; // 設定新的代幣位址
    }

    // 創建新棋局的函式，初始化賭注並等待對手
    function createGame(uint256 _stake) public returns (uint256) {
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), _stake), "Transfer failed");

        uint256[15][15] memory initialBoard; // 初始化棋盤
        games[gameCount] = Game({
            black: address(0),
            white: address(0),
            stake: _stake,
            winner: address(0),
            board: initialBoard,
            turn: true,
            active: false,
            waitingForOpponent: true
        });

        gameCount++; // 遊戲計數增加
        return gameCount - 1; // 返回新遊戲的 ID
    }

    // 對手加入遊戲，並隨機分配黑白棋方
    function joinGame(uint256 _gameId) public {
        Game storage game = games[_gameId];
        require(game.waitingForOpponent, "Game is not waiting for an opponent");
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), game.stake), "Transfer failed");

        // 隨機分配黑白棋方
        bool isBlack = (block.timestamp % 2 == 0);
        if (isBlack) {
            game.black = msg.sender;
            game.white = game.black;
        } else {
            game.white = msg.sender;
            game.black = game.white;
        }

        game.stake *= 2; // 更新總賭注數量
        game.active = true; // 啟動遊戲
        game.waitingForOpponent = false; // 更新等待對手狀態
    }

    // 下棋的函式
    function makeMove(uint256 _gameId, uint8 x, uint8 y) public {
        Game storage game = games[_gameId]; // 獲取遊戲狀態
        require(game.active, "Game has already ended"); // 檢查遊戲是否進行中
        require(game.board[x][y] == 0, "This position is already occupied"); // 檢查位置是否已有棋子
        require(
            (game.turn && msg.sender == game.black) || (!game.turn && msg.sender == game.white),
            "Not your turn" // 檢查是否輪到該玩家
        );

        // 放置棋子
        game.board[x][y] = game.turn ? 1 : 2;
        game.turn = !game.turn; // 更換回合

        // 檢查是否有人贏得遊戲
        if (checkWinner(_gameId, x, y)) {
            game.winner = msg.sender;
            payoutStakes(_gameId); // 處理賭注轉移
        }
    }

    // 檢查是否有人贏得遊戲的函式
    function checkWinner(uint256 _gameId, uint8 x, uint8 y) internal view returns (bool) {
        uint256[15][15] storage board = games[_gameId].board;
        uint256 player = board[x][y];
        require(player != 0, "No stone in the given position"); // 檢查該位置是否有棋子

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

    // 投降的函式
    function surrender(uint256 _gameId) public {
        Game storage game = games[_gameId]; // 獲取遊戲狀態
        require(game.active, "Game has already ended"); // 檢查遊戲是否進行中
        require(msg.sender == game.black || msg.sender == game.white, "You are not a player in this game");

        game.active = false; // 結束遊戲
        game.winner = msg.sender == game.black ? game.white : game.black; // 設定勝者
        payoutStakes(_gameId); // 處理賭注轉移
    }

    // 緊急停止所有遊戲的函式（僅限管理員）
    function emergencyStop() public {
        // 加入管理權限檢查
        // 修改相關狀態以阻止所有遊戲進行
    }

    // 輔助函式，用於計算從一個位置開始沿特定方向的連續同色棋子數量
    function countStones(uint256[15][15] storage board, uint8 startX, uint8 startY, int8 dirX, int8 dirY)
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

    // 結束遊戲並處理賭注
    function payoutStakes(uint256 _gameId) internal {
        Game storage game = games[_gameId]; // 從遊戲映射中獲取指定 ID 的遊戲狀態
        require(game.active, "Game is not active, unable to settle stakes"); // 確保遊戲正在進行中，否則無法進行結算
        require(game.winner != address(0), "No winner, unable to settle stakes"); // 確保已經有勝利者，否則無法進行結算

        game.active = false; // 將遊戲狀態標記為非進行中
        bool sent = IERC20(tokenAddress).transfer(game.winner, game.stake); // 將賭注金額從合約轉至勝利者地址
        require(sent, "Stake transfer failed"); // 確認賭注轉移成功，否則拋出錯誤

        game.stake = 0; // 將賭注金額重設為 0，以防萬一
    }
}
