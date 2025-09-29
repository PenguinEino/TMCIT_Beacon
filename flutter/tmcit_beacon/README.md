# TMCIT Beacon Scanner

FlutterでiOS/Androidで動作するiBeacon検出アプリです。

## 主な機能

- **iBeacon検出**: 指定したUUIDのiBeaconを自動検出
- **リアルタイム監視**: ビーコンの距離、RSSI、Major/Minorをリアルタイムで表示
- **バックグラウンド対応**: アプリがバックグラウンドでも継続的にビーコンを検出
- **タブナビゲーション**: スキャナーと検出結果を分けて表示
- **検索機能**: 検出されたビーコンをMajor、Minor、UUIDで検索

## 対象iBeacon

- **UUID**: `4b206330-cf87-4d78-b460-acc3240a4777`
- 上記UUIDに一致するiBeaconのみを検出・表示します

## 必要な権限

### Android
- `ACCESS_FINE_LOCATION` - 位置情報（精密）
- `ACCESS_BACKGROUND_LOCATION` - バックグラウンド位置情報
- `BLUETOOTH_SCAN` - Bluetooth Low Energy スキャン
- `BLUETOOTH_ADVERTISE` - Bluetoothアドバタイズ

### iOS
- `NSLocationWhenInUseUsageDescription` - 使用中の位置情報
- `NSLocationAlwaysAndWhenInUseUsageDescription` - 常時位置情報
- `NSBluetoothAlwaysUsageDescription` - Bluetooth使用許可

**重要**: バックグラウンドでのビーコン検出には位置情報を「常に許可」に設定する必要があります。

## 使用方法

1. **アプリ起動**: アプリを起動すると自動的にBeaconサービスが初期化されます
2. **権限許可**: 位置情報とBluetoothの権限を許可してください
3. **スキャン開始**: 「Scanner」タブで「Start Scanning」ボタンを押します
4. **結果確認**: 「Detected Beacons」タブで検出されたビーコンの詳細を確認できます

## 技術スタック

- **Flutter**: UI フレームワーク
- **dchs_flutter_beacon**: iBeacon検出ライブラリ
- **permission_handler**: 権限管理

## セットアップ

```bash
# 依存関係をインストール
flutter pub get

# アプリを実行（実機のみ対応）
flutter run
```

**注意**: iBeacon機能はシミュレーターでは動作しません。実機でのテストが必要です。

## プロジェクト構造

```
lib/
├── main.dart                 # アプリケーションエントリーポイント
├── models/
│   └── beacon_data.dart      # ビーコンデータモデル
├── services/
│   └── beacon_service.dart   # ビーコン検出サービス
└── screens/
    ├── home_screen.dart      # タブナビゲーション
    ├── scanner_screen.dart   # スキャナー画面
    └── beacon_list_screen.dart # 検出結果一覧画面
```

## トラブルシューティング

### iOS 13+ でビーコンが断続的にしか検出されない
iOS 13以降では、ビーコンの検出が断続的になる問題があります。以下の設定で改善する場合があります：

```dart
await flutterBeacon.setScanPeriod(1000);
await flutterBeacon.setBetweenScanPeriod(500);
```

### Android開発者オプション
Androidのデバッグモードでは、「Bluetooth A2DP ハードウェア オフロード」を無効にするとビーコン検出が安定する場合があります。

## ライセンス

このプロジェクトはApache 2.0ライセンスの下で公開されています。
