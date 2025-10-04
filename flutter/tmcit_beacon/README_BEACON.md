# TMCIT Beacon Scanner

FlutterでiOS/Androidで動作するiBeacon検出アプリです。

## 機能

- ✅ iBeaconの検出とモニタリング
- ✅ 特定UUID（4b206330-cf87-4d78-b460-acc3240a4777）のビーコンをレンジング
- ✅ Major、Minorの記録
- ✅ RSSI（信号強度）と推定距離の表示
- ✅ タブベースのUI（スキャンタブ、ビーコン一覧タブ）
- ✅ バックグラウンド動作対応

## 使用ライブラリ

- [dchs_flutter_beacon](https://pub.dev/packages/dchs_flutter_beacon) - iBeaconスキャン機能
- [permission_handler](https://pub.dev/packages/permission_handler) - 位置情報・Bluetooth権限管理

## セットアップ

### 1. 依存関係のインストール

```bash
flutter pub get
```

### 2. iOS設定

すでに`ios/Runner/Info.plist`に以下の権限が設定されています：

- `NSLocationWhenInUseUsageDescription` - アプリ使用時の位置情報
- `NSLocationAlwaysAndWhenInUseUsageDescription` - バックグラウンドでの位置情報
- `NSBluetoothAlwaysUsageDescription` - Bluetooth使用権限
- `UIBackgroundModes` - location, bluetooth-central

### 3. Android設定

すでに`android/app/src/main/AndroidManifest.xml`に以下の権限が設定されています：

- Bluetooth関連権限（BLUETOOTH, BLUETOOTH_ADMIN, BLUETOOTH_SCAN, BLUETOOTH_CONNECT）
- 位置情報権限（ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION）
- フォアグラウンドサービス権限（FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION）

## 実行方法

### iOS実行

```bash
cd /home/penguin/TMCIT_Beacon/flutter/tmcit_beacon
flutter run -d ios
```

### Android実行

```bash
cd /home/penguin/TMCIT_Beacon/flutter/tmcit_beacon
flutter run -d android
```

## 使い方

### 1. スキャンタブ

- **初回起動時**: 位置情報の「常に許可」権限を求められます
  - 画面の指示に従って「常に許可」を選択してください
  - 「使用中のみ許可」では、バックグラウンドでのビーコン検出ができません
- 権限状態が画面上部のカードに表示されます：
  - 🟢 緑: 常に許可（スキャン可能）
    - iOS: 「常に」が設定されている
    - Android: 「常に許可」が設定されている
  - 🟠 オレンジ: 使用中のみ許可（不十分）
    - iOS: 「使用中のみ許可」のまま
    - Android: 「アプリの使用中のみ」のまま
    - ⚠️ この状態ではバックグラウンドでBeaconを検出できません
  - 🔴 赤: 未許可または拒否済み
- **スキャン開始**ボタンをタップしてiBeaconの検出を開始
  - ターゲットUUID: `4b206330-cf87-4d78-b460-acc3240a4777`
- **スキャン停止**ボタンでスキャンを停止
- **検出履歴をクリア**で記録をクリア

**デバッグ機能（右下のボタン）：**
- 🐛 **虫アイコン**: デバッグログを表示
  - アプリ内の動作状況をリアルタイムで確認できます
  - 権限状態の遷移、エラー情報などが表示されます
  - **タップでコピー**: ログ行をタップするとクリップボードにコピー
  - **長押しで詳細**: ログ行を長押しすると詳細ダイアログを表示
  - **📋 一括コピー**: ヘッダーのアイコンで全ログをコピー
  - **🗑️ クリア**: ヘッダーのアイコンでログをクリア
- 👁️ **目のアイコン**: デバッグログのON/OFF
  - OFFの場合、ログは記録されません（パフォーマンス向上）
  - ONの場合、オレンジ色に変わります

### 2. ビーコン一覧タブ

- 検出されたすべてのビーコンを一覧表示
- 各ビーコンの詳細情報：
  - UUID
  - Major / Minor
  - RSSI（信号強度）
  - 推定距離
  - 検出時刻
- 信号強度を色で表示（強：緑、中：オレンジ、弱：赤）

## バックグラウンド動作

iOS/Android共に、バックグラウンドでのビーコン検出に対応しています。

- **iOS**: Background Modesで`location`と`bluetooth-central`を有効化
- **Android**: フォアグラウンドサービスとして動作

## プロジェクト構成

```
lib/
├── main.dart                    # アプリエントリーポイント
├── models/
│   └── detected_beacon.dart     # ビーコンデータモデル
├── screens/
│   └── home_screen.dart         # メイン画面（タブ管理）
├── services/
│   ├── beacon_service.dart      # ビーコンスキャンロジック
│   └── debug_log_service.dart   # デバッグログサービス
└── widgets/
    ├── scan_tab.dart            # スキャンタブUI
    ├── beacon_list_tab.dart     # ビーコン一覧タブUI
    └── debug_log_dialog.dart    # デバッグログビューア
```

## 技術的な詳細

### 権限管理の実装

このアプリは`permission_handler`パッケージを使用して、iOS/Android両方で正確な権限状態を管理しています。

**dchs_flutter_beaconの制限:**
- iOS: アプリ内からの権限取得直後、`authorizationStatus`が不正確な値を返すことがある
- Android: `ALLOWED`のみを返し、「使用中のみ」と「常に許可」を区別できない

**解決策:**
```dart
// permission_handlerを使用した正確な判定
final alwaysStatus = await Permission.locationAlways.status;
final whenInUseStatus = await Permission.locationWhenInUse.status;

if (alwaysStatus.isGranted) {
  // ✅ バックグラウンド検出可能
} else if (whenInUseStatus.isGranted) {
  // ⚠️ フォアグラウンドのみ
}
```

## トラブルシューティング

### 位置情報の権限を「常に許可」に変更する方法

#### iOS
iOSでは2段階の手順が必要です：

**初回権限リクエスト時：**
1. 「使用中のみ許可」または「アプリの使用中は許可」を選択
2. アプリが自動的に設定画面への移動を促すダイアログを表示
3. 「設定を開く」をタップ
4. 設定アプリで「位置情報」→「常に」を選択
5. アプリに戻る

**手動で変更する場合：**
1. 設定アプリを開く
2. アプリ一覧から「TMCIT Beacon」を選択
3. 「位置情報」をタップ
4. 「常に」を選択

**重要:** iOSでは、最初のシステムダイアログで「常に許可」を直接選択できません。必ず「使用中のみ許可」を選んでから、設定アプリで「常に」に変更する必要があります。

#### Android
Androidでも「常に許可」が必須です：

**初回権限リクエスト時（推奨）：**
1. 最初のダイアログで「アプリの使用中のみ」を選択
2. 次に表示されるダイアログで「常に許可」を選択
3. **注意**: 「使用中のみ」だけを選択すると、バックグラウンドでBeaconを検出できません

**手動で変更する場合：**
1. 設定アプリを開く
2. アプリ一覧から「tmcit_beacon」を選択
3. 権限 → 位置情報
4. 「常に許可」を選択

### iOSでビーコンが検出されない場合

1. 実機でテストしていることを確認（シミュレータではBluetoothが動作しません）
2. 設定 → プライバシーとセキュリティ → 位置情報サービスで、アプリの権限が「常に」に設定されていることを確認
3. Bluetoothがオンになっていることを確認
4. アプリを再起動してみる

### Androidでビーコンが検出されない場合

1. 位置情報がオンになっていることを確認
2. Bluetoothがオンになっていることを確認
3. **重要**: アプリの位置情報権限が「常に許可」になっていることを確認
   - 設定 → アプリ → tmcit_beacon → 権限 → 位置情報 → 「常に許可」
   - 「アプリの使用中のみ」では、バックグラウンドでBeaconを検出できません
4. アプリにBluetooth権限が付与されていることを確認
5. 開発者オプションで「Bluetooth A2DP Hardware Offload」を無効化してみる

### iOS 13+でビーコンがすぐに消える場合

サービスコードに以下を追加することで改善できます：

```dart
await flutterBeacon.setScanPeriod(1000);
await flutterBeacon.setBetweenScanPeriod(500);
await flutterBeacon.setUseTrackingCache(true);
await flutterBeacon.setMaxTrackingAge(10000);
```

## ライセンス

このプロジェクトは個人使用のためのものです。
