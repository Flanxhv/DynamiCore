# DynamiCore
DynamiCore是音樂遊戲「Dynamix」的社區作品－－「Dynamite」的模仿版本。
此遊戲並無Dynamix、Dynamite製作人員的參與。

## 不同之處
遊戲大多參考了Dynamite，但有以下不同：
* 沒有段位機制、單曲排行榜、R值、Coin、體力。
* 分數計算使用ACC制，顯示的分數為百分比的ACC換算至1000000尺度下(對應評級則是隨意劃分的區間，無參考價值)。
* 遊玩判定上，去除了一部分原作與Dynamite存有的防糊機制。具體來說，目前可以以雙押手法接取不同時機的兩顆音符，而不會因防糊機制使其中一顆變為MISS(但仍會受一般判定)。
* 打擊特效不太一樣。
* 添加了Import功能：點擊後可導入裝置內的譜面至本機遊戲中。
導入需要準備一個.zip壓縮檔，裡面放置譜面文件(以Dynamix標準難度名稱大寫為名的.xml檔案，例: MEGA.xml)、音樂檔案、背景檔案以及一份meta.json用於記錄曲目相關資訊，前述有標示檔案名稱的文件須按照格式，否則無法導入。

可以複製一份下列的meta.json內容來順利導入：
{
"id": "test1111111",
"title": "TEST",
"artist": "TEST",
"charter": "YOU",
"difficulty": [
"MEGA 13", "GIGA 15"
]
}

## 使用資源
* 遊戲內的雲端下載歌曲、譜面、曲繪等，皆是取用Dynamite-Explode的資源請求連結，具體可參考https://www.bilibili.com/opus/929119967227412502?from=search&spm_id_from=333.337.0.0
* 更新：由於目前Dynamite Explode伺服器搬遷中，先前下載功能因此無法使用，目前將下載請求轉移至Reboot服務器（具體參考了https://www.bilibili.com/opus/1132741888552468497?from=search&spm_id_from=333.337.0.0）。據此，目前僅能下載Reboot服擁有的譜面。
個人租借了一個簡易資料庫，目前會將請求完的譜面、音樂、封面等結果同步存放至該資料庫，即使Reboot伺服器出現突發意外，也還能下載這些曾請求過的譜面。
* 主介面的BGM朧月，來自musmus(https://musmus.main.jp/piano.html)。
* 關於常駐曲目「Rain then clear」:此曲目係由本人向作曲家「kuro」於Skeb平台上約稿所得，在約稿中已聲明此曲將會以非盈利方式添加至遊戲中。依據Skeb的規定，樂曲版權仍歸屬於作曲家，請勿隨意挪用歌曲。

## 關於iOS
更新會打包一份.ipa供iOS玩家使用，但由於本人未持有簽署所需的Apple ID，故需要使用電腦以側載的方式手動簽署並安裝(若要長期遊玩，需要每隔7天手動重簽署一次)，具體可參考專欄 https://www.bilibili.com/opus/669766052122460160 。
此外，我沒有Apple裝置和任何系統的平板，故無法測試.ipa是否能正常使用及BUG，以及此遊戲在平板比例上的表現，敬請見諒。

## 聲明
此遊戲開發過程與發行皆無盈利，若本遊戲使用素材有侵犯權利之虞，請告知我，我會調整或下架此專案。
此遊戲開發過程多為AI Vibe Code。
