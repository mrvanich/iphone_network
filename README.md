# Network Scanner (iPhone)

Сканер локальної Wi-Fi мережі: знаходить камери Hikvision / Dahua та інші пристрої.
Працює **без** спецдозволів Apple (підходить для безкоштовного Apple ID).

## Як це працює
1. Беремо IP і маску Wi-Fi (en0), перебираємо всі адреси підмережі.
2. TCP-перевірка портів 80, 443, 554, 8000, 8080, 8899, 37777.
3. Для хостів з веб-портом — HTTP-запити без авторизації (`/`, `/ISAPI/System/deviceInfo`, `/cgi-bin/magicBox.cgi`) і розбір заголовків (`Server`, `realm`).
4. Фірмові порти: 37777 → Dahua, 8000+554 → Hikvision.
5. Після скану читаємо ARP-кеш → MAC → виробник за OUI (best effort).

## Запуск
```
brew install xcodegen
cd iphone_network
xcodegen generate
open NetworkScanner.xcodeproj
```
В Xcode: target NetworkScanner → Signing & Capabilities → Team = ваш Apple ID.
Підключіть iPhone, виберіть його як ціль, Run. На телефоні: Налаштування → Основні →
VPN та керування пристроєм → довіряти розробнику.

Без xcodegen: Xcode → New Project → iOS App (SwiftUI), видалити стандартні файли,
перетягнути папку `NetworkScanner`, додати в Info ключ `NSLocalNetworkUsageDescription`.

## Важливо
- Першого запуску iOS питає «Local Network» — дозвольте і запустіть скан ще раз.
- Симулятор мережу сканує обмежено — тестуйте на iPhone.
- MAC може бути недоступний (залежить від iOS); тоді вендор визначається за портами/відповідями.
- Скануйте лише власні мережі або ті, де маєте дозвіл.
