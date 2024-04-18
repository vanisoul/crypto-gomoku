# CryptoGomoku

**警告：此專案目前處於開發初期階段，尚未實現完全的功能。 目前只提供基礎的智慧合約樣板和文件說明，還無法直接使用。 **

CryptoGomoku 是一個基於以太坊的去中心化五子棋遊戲，透過智能合約來處理遊戲邏輯，保證遊戲的公平性與透明性。

## 功能特點

- **完全去中心化**：所有遊戲邏輯完全在智能合約中執行，不依賴中心化伺服器。
- **透明可驗證**：遊戲過程和結果公開存儲於區塊鏈上，任何人都可進行驗證。
- **區塊鏈互動**：玩家透過區塊鏈錢包與遊戲互動，增加了使用的安全性和便利性。

## 技術棧

- **Solidity**：智能合約開發語言。
- **Foundry**：用於智能合約的開發、測試和部署。

## 快速開始

遵循以下步驟來在部屬 CryptoGomoku：

### 前提條件

確保您已安裝 Git，以及安裝並配置了 Foundry。
如果沒有安裝 Foundry，您可以造訪 [Foundry 官網](https://github.com/foundry-rs/foundry?tab=readme-ov-file#installation) 下載並安裝。

### 安裝

克隆倉庫到本地：

```bash
git clone https://github.com/yourusername/CryptoGomoku.git
cd CryptoGomoku
```

### 編譯合約
`forge build`

### 測試合約
執行以下命令來運行合約測試：
`forge test`

### 啟動本地網路
首先啟動本地以太坊網絡（Foundry 自帶的 anvil）： `anvil` 並且會生成測試用地址與私鑰

### 部署智能合約
然後部署合約：`forge create --rpc-url http://localhost:8545 --private-key [私鑰] src/Counter.sol:Counter`
- $RPC_URL：請填寫您的以太坊網路的 RPC 位址，例如 http://localhost:8545 。
- $PRIVATE_KEY：使用部署合約的帳戶的私鑰。出於安全考慮，請在開發環境中使用測試帳戶的私鑰，並確保不在生產環境或公開環境中暴露您的私鑰。