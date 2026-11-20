# Dynamic Island for KDE Plasma

Wayland 上の KDE Plasma 6 向けに、画面上部のノッチ／ピルとして動作する常駐ユーティリティです。再生中のメディア表示、音量やデスクトップ通知の統合アラート、カレンダー・天気・タイマー・各種ツールを備えたパネルを提供します。

Arch 系環境向けに Notchy に着想を得て、Claude をコーディングアシスタントとして開発しました。動作検証は主に開発環境（CachyOS / KDE Plasma 6 / Wayland）で行っています。

実データ（デモ用データ）で録画した 16 秒の紹介動画はこちらです：

https://github.com/user-attachments/assets/41d47ead-64d6-4dfa-99cd-7c2cd56dae01

## 主な機能

### 閉じたピル

- **メディア・タイマー表示**：音楽の再生中はカバーアートと小型のオーディオレベルメーター、タイマー動作中はカウントダウンを表示します。両方が同時に動いている場合は自動で交互に切り替わり、タッチパッドの左右スワイプで手動切り替えもできます。
- **アイドル表示（グランス／アニメーション）**：再生やタイマーがないときは、グランス（まもなく始まる予定、バッテリー低下、時刻、天気、待機中のシステム更新数〈初期設定ではオフ〉）またはアニメーション（オーロラ、ウェーブ、ホタル、ドット絵の猫、カスタム GIF / WebP）を表示します。
- **ファイル操作・ダウンロード進捗**：ダウンロード、コピー、展開などのジョブ実行中はピル表示のローテーションに加わり、ファイル名（または「N 件のジョブ」）、全体の進捗率、下端の細いプログレスバーを表示します。カーソルを合わせると各ジョブの詳細と残り時間を確認でき、音楽やタイマー表示中も小さな青いチップで実行中のジョブをお知らせします。
- **クイックアクセス**：カーソルを合わせると曲名を表示し、クリックまたはどこからでも `Meta+N` でパネルを開閉できます（再度 `Meta+N` または `Esc` で閉じます）。ショートカットキーは「システム設定 → ショートカット」から変更可能です。
- **2種類のスタイル**：画面上端に密着する「ノッチ」と、少し浮かせて表示する「ピル」をアニメーション付きで切り替えられます。

### 通知・ショートアラート

- **システム OSD の統合**：音量、画面の明るさ、Caps Lock のオン／オフをピル内に表示し、Plasma 標準の OSD ポップアップを置き換えます。
- **デスクトップ通知の統合**：Plasma 標準の通知ポップアップを置き換え、クリックすると通知元のアプリを開きます。
- **通知履歴の自動保存**：おやすみモード中、画面ロック中、またはパネル展開中に届いてポップアップ表示されなかった通知も含め、すべての通知を保存します。アイドル時のピルには未確認件数を示すオレンジ色のベルチップが表示されます。
- **ジョブ完了・エラーアラート**：ダウンロードやコピーの完了・失敗を知らせます。完了アラートをクリックすると保存先フォルダを開きます。
- **デバイス・電源アラート**：アプリによるマイクやカメラの使用開始、Bluetooth デバイスの接続、電源アダプターの接続／切断を通知します。
- **フルスクリーンアプリ上での表示**：フルスクリーンゲームや動画再生中でもアラートを一時的に前面表示できます。通知については「設定 → アラート → フルスクリーンアプリ上での表示」で種類ごとにオン／オフでき、既定では「緊急アプリ」リストに登録したアプリまたは重要度が critical の通知のみを表示します（「すべての通知を表示」を有効にすると全件表示されます）。

### パネルタブ

- **ホーム**：音楽プレイヤー、月間カレンダー、数時間先の天気予報、直近の予定（Google Meet / Zoom / Microsoft Teams リンクの参加ボタン付き）、タイマーをまとめて表示します。
- **音楽**：カバーアートの色味に合わせた柔らかなグロー演出、シークバー、シャッフル、リピート、プレイヤー個別の音量調整に対応します。
- **タイマー**：分単位のメモリテープをドラッグして直感的に時間を設定できるほか、プリセットからも選択できます。
- **サウンドミキサー**：出力デバイス・入力デバイスの切り替え、マイク入力レベル、アプリごとの音量調整が行えます。
- **通知**：過去 7 日間（保持日数は変更可能）の保存済み通知をアプリごとにまとめて表示し、未読マークを付けます。項目をクリックすると該当アプリが開きます。保持期間や保存対象の種別・アプリは設定画面から調整できます。
- **`⋯` メニュー（各種ツール）**：クリップボード履歴、メモ、ドラッグ＆ドロップしたファイルを一時保管できるシェルフ、よく使うサイトやフォルダへのクイックリンク、カラーピッカーを利用できます。

### クイックボタン

パネル上部に、バッテリー、音量、Wi-Fi、Bluetooth、おやすみモード、画面スリープ抑止、スクリーンショット、画面ロックのクイックボタンを備えています。

## 動作要件

- **Wayland 上の KDE Plasma 6**：layer-shell サーフェスおよび KWin / Plasma の DBus サービスを使用するため、X11 や他のデスクトップ環境では動作しません。
- **ブラウザのダウンロード表示**：ブラウザ側のダウンロード進捗を表示するには、Plasma Browser Integration アドオンが必要です。
- **Plasma プライベート QML モジュール**：Plasma 内部の MPRIS および音量 QML モジュールをインポートしているため、Plasma のメジャーアップデート等により音楽・ミキサー表示に影響が出る場合があります。

### Arch Linux での必要パッケージ

```sh
sudo pacman -S --needed cmake ninja qt6-base qt6-declarative qt6-shadertools \
    layer-shell-qt kcalendarcore kguiaddons kconfig kidletime kglobalaccel \
    plasma-workspace plasma-pa wireplumber networkmanager bluez-utils spectacle
```

クイックボタンは内部で `wpctl`、`nmcli`、`bluetoothctl`、`spectacle`、`loginctl` を呼び出します。

## ビルドと実行

用途に応じて **汎用版** と **この端末向け完全最適化版** の 2 種類をビルドできます。

### 1. 汎用版（Generic）

どの x86-64 環境でも動作するポータブルなリリースビルドです（`-O3` + LTO）。

```sh
cmake -S . -B build-generic -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DDYNAMIC_ISLAND_NATIVE=OFF \
    -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build build-generic -j"$(nproc)"
./build-generic/dynamic-island
```

### 2. この端末向け完全最適化版（Native）

ビルドを実行するマシンの CPU アーキテクチャに特化して最適化するビルドです（`-O3 -march=native -mtune=native` + LTO + リンク時デッドコード除去）。※ 生成されたバイナリはビルドした端末（または同世代以降の CPU）専用となります。

```sh
cmake -S . -B build-native -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DDYNAMIC_ISLAND_NATIVE=ON \
    -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build build-native -j"$(nproc)"
./build-native/dynamic-island
```

### 主な CMake オプション

| オプション | 既定値 | 説明 |
| --- | --- | --- |
| `CMAKE_BUILD_TYPE` | `Release` | 未指定時は自動で `Release` になります。 |
| `DYNAMIC_ISLAND_NATIVE` | `OFF` | `ON` にすると `-march=native -mtune=native` を有効化し、ビルド端末向けに完全最適化します。 |
| `DYNAMIC_ISLAND_LTO` | `ON` | Release ビルドで LTO / IPO（リンク時最適化）を有効化します。 |

### インストール

ビルドしたバイナリと `.desktop` ファイルをインストールし、アプリケーションメニューへ登録します（`build-native` または `build-generic` のいずれかを指定）：

```sh
cmake --install build-native
```

ログイン時の自動起動は「設定 → 一般」の「ログイン時に起動」スイッチから有効化できます。

## リリースビルド（2 種類の一括ビルド）

付属のスクリプトを実行すると、**汎用版 (`generic`)** と **この端末向け完全最適化版 (`native`)** の両方を一度にビルドし、`release/` ディレクトリへ一式を出力します。

```sh
./scripts/build-release.sh 1.1.0
```

出力される成果物（`release/` 配下）：

- そのまま実行できるバイナリ：
  - `release/dynamic-island-generic`（汎用版：`-O3` + LTO）
  - `release/dynamic-island-native`（完全最適化版：`-O3 -march=native -mtune=native` + LTO）
- インストール用アーカイブ（`/usr/local` 基準のポータブル構成）：
  - `release/dynamic-island-<version>-generic.tar.xz`
  - `release/dynamic-island-<version>-native.tar.xz`
  - 例：`sudo tar -C / -xJf release/dynamic-island-1.1.0-generic.tar.xz` で `/usr/local` に展開できます。
- チェックサム：
  - `release/dynamic-island-<version>-SHA256SUMS` / `release/SHA256SUMS`

## テスト

QML テストおよび C++ ユニットテストは `ctest` で実行できます：

```sh
ctest --test-dir build-generic --output-on-failure
ctest --test-dir build-native --output-on-failure
```

## 設定と外部サービス連携

パネルの歯車アイコンから設定ウィンドウを開けます。スタイルやアクセントカラー、サイズ、各種動作、表示するアラートの種類、アイドル時ピルの設定、カレンダー、天気、クイックボタン、クイックリンクなどを細かく調整できます。

### カレンダー（iCal）連携

予定を表示するには、カレンダーの「iCal 形式の非公開 URL」を設定画面に貼り付けます（Google カレンダーの場合：設定 → 対象カレンダー → カレンダーの統合 → iCal 形式の非公開 URL）。登録した URL はローカルの設定ファイルにのみ保存され、画面への再表示やログ出力は一切行われません。

### 天気情報

天気データは [Open-Meteo](https://open-meteo.com) から取得します。現在地は `geojs.io` を通じて IP アドレスから自動判定されるほか、設定画面で任意の都市を手動指定することもできます。

## 日本語 UI と翻訳の更新

このアプリの UI は日本語専用です。組み込み済みの日本語翻訳カタログ（`:/i18n/translations/dynamic-island-ja.qm`）がデスクトップの言語設定に関わらず適用されるため、英語環境のデスクトップ上でも日本語で表示されます（未翻訳の文字列がある場合は英語ソース文字列にフォールバックします）。

`qml/` 内の `qsTr()` 文字列を変更したあとに翻訳カタログを更新する手順は次のとおりです：

```sh
/usr/lib/qt6/bin/lupdate -recursive qml -ts translations/dynamic-island-ja.ts   # qsTr() 呼び出しを収集
/usr/lib/qt6/bin/lrelease translations/dynamic-island-ja.ts                    # .qm をコンパイル（CMake で自動埋め込み）
```

`.ts` ファイルは Qt Linguist で編集することもできます。`lrelease` 実行後に再ビルドすると、新しい `.qm` が実行ファイルに組み込まれます。

## データの保存先

- **設定ファイル**：`~/.config/dynamic-island.conf`（カレンダーの非公開 URL を含む場合があるため、所有者のみ読み取り可能なパーミッションで保存されます）
- **クリップボード履歴**：`~/.local/share/dynamic-island/clipboard`
- **メモ**：`~/.local/share/dynamic-island/notes`（1 メモにつき 1 つのテキストファイル）
- **保存された通知履歴**：`~/.local/share/dynamic-island/notifications.json`（通知本文を含むため、所有者のみ読み取り可能なパーミッションで保存されます）

## ライセンス

MIT ライセンスです。詳細は [LICENSE](LICENSE) を参照してください。
