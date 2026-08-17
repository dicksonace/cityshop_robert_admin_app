# CityShop Admin

Separate Flutter app for CityShop administrators. It installs beside the shopper/seller app (`com.cityshop.cityshop_mobile`) as `com.cityshop.cityshop_admin`.

Sign in with an **admin** account (`portal=admin`). Shoppers and sellers cannot use this app.

```bash
cd cityshop/admin_mobile
flutter pub get
flutter run
flutter build apk --release
```

The release APK is written to `build/app/outputs/flutter-apk/app-release.apk`.
