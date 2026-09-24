# VIRBMapFix — патч карты для Garmin VIRB Edit

Исправляет неработающую карту в **Garmin VIRB Edit 5.4.3** (белый экран и
«Ошибка сценария … `maps/api/js?v=3.12`» в окне синхронизации G-Metrix).

> **EN summary:** VIRB Edit renders its sync map with the legacy Internet Explorer
> engine, which Google Maps no longer supports. This patch serves a local
> IE11-compatible [Leaflet](https://leafletjs.com/) replacement
> (CyclOSM streets + Esri World Imagery with labels, zoom up to 22) instead of Google Maps, keeping the
> original JS bridge so G-Metrix track sync keeps working. No Python needed,
> pure PowerShell + a tiny native launcher (no VBScript). The local server runs only while VIRB Edit is open
> (shortcuts are repointed to a hidden launcher, no background task). See [README-EN](#english) below for details.

## Почему ломается

VIRB Edit грузит страницу карты со `static.garmincdn.com`, а та тянет
Google Maps API `v=3.12` во встроенном IE. Google прекратил поддержку IE:
с 2022 года помогает правка реестра (`FEATURE_BROWSER_EMULATION`), а с
августа 2023 ломаются уже `marker.js` / `controls.js` — пропадает красный
маркер, синхронизация невозможна. Реестром это больше не лечится.

## Что делает патч

1. Реестр `FEATURE_BROWSER_EMULATION`: `VirbEdit.exe = 0x2ee1` (режим IE11).
2. Подменяет удалённую страницу карты локальной на Leaflet 1.7.1
   (совместим с IE11) + CyclOSM (улицы, зум до 20) / Esri World Imagery
   с подписями (названия и дороги поверх снимков), приближение до 22.
   JS-мост с программой (`SetTrack`, `SetMarkerPosition`, перетаскивание
   маркера и т.д.) сохранён 1:1, синхронизация G-Metrix работает.
3. `hosts`: `127.0.0.1 static.garmincdn.com` (VIRB просит карту по `http`,
   сертификаты не нужны; остальной контент CDN проксируется).
4. Локальный HTTP-сервер (PowerShell, без зависимостей) на `127.0.0.1:80`,
   который работает **только пока открыт VIRB Edit**: установщик
   переписывает ярлыки VIRB Edit (меню Пуск, рабочие столы, панель задач)
   на скрытый лаунчер — запуск программы сначала поднимает сервер, а после
   закрытия последнего окна VIRB Edit сервер останавливается. Фоновой
   задачи в планировщике и окон PowerShell при загрузке Windows нет.

## История версий

* **v1.4** — карта: улицы CyclOSM вместо OSM Standard, на спутник добавлены
  подписи Esri (названия и дороги), приближение увеличено до 22
  (дальше родного зума тайлов — растяжка Leaflet).

* **v1.3** — отказ от VBScript (`VirbEdit-Launcher.vbs` удалён: VBScript
  deprecated в Windows): скрытый запуск через нативный
  `VirbEdit-Launcher.exe` (C#, сборка штатным `csc.exe`, см.
  `src/`); ярлыки читаются/пишутся через `IShellLink` без `WScript.Shell`,
  ошибки показываются через `MessageBox`. Ярлыки от v1.2 мигрируют
  автоматически.

* **v1.2** — отказ от IFEO-перехвата (отладчик перехватывал и запуск из
  самого лаунчера — рекурсия, программа не стартовала) в пользу
  переписанных ярлыков.

* **v1.1** — запуск сервера по требованию (IFEO-лаунчер вместо задачи
  планировщика с автозапуском при загрузке); фиксы: пустой `-ArgumentList`
  в лаунчере, fallback префиксов `HttpListener` без `[::1]`, резервация
  `urlacl` для `[::1]:80`, права на лог-файлы.
* **v1.0** — первый выпуск (сервер висел в фоне через задачу `VIRBMapFix`).

## Установка

1. Скачайте архив из [Releases](../../releases) и распакуйте.
2. Запустите **`install.bat`**, подтвердите права администратора.
3. Дождитесь «Готово».
4. Полностью закройте VIRB Edit (если был открыт) и откройте заново.
5. Откройте G-Metrix журнал — карта должна появиться.

Быстрая проверка (карта доступна, только пока открыт VIRB Edit):

```text
http://static.garmincdn.com/desktop-chandler/virbedit/maps/v8/google/index.html
```

Должна открыться карта мира с кнопками Map / Satellite.

Требования: Windows 10/11, права администратора на время установки,
интернет (тайлы CyclOSM/Esri грузятся из сети), свободный порт 80.

## Удаление

Запустите **`uninstall.bat`** (права администратора).
Запись реестра `VirbEdit.exe` при этом оставляется — она безвредна.

## Файлы после установки

```text
C:\ProgramData\VIRBMapFix\server.ps1            — сервер
C:\ProgramData\VIRBMapFix\VirbEdit-Launcher.ps1 — лаунчер «сервер только пока открыт VIRB Edit»
C:\ProgramData\VIRBMapFix\VirbEdit-Launcher.exe — скрытый вход лаучера (цель переписанных ярлыков, без VBScript)
C:\ProgramData\VIRBMapFix\Repair-Shortcuts.ps1  — переписывание/возврат ярлыков VIRB Edit
C:\ProgramData\VIRBMapFix\www\...               — страницы карты
C:\ProgramData\VIRBMapFix\server.log            — лог запросов сервера
C:\ProgramData\VIRBMapFix\launcher.log          — лог запусков/остановок сервера
```

## English

**Problem:** the G-Metrix sync window in VIRB Edit shows a blank map and a
script error for `maps/api/js?v=3.12`. VIRB Edit embeds Internet Explorer to
display Google Maps, which Google no longer supports — since Aug 2023 even
the well-known registry workaround (`FEATURE_BROWSER_EMULATION = 0x2ee1`)
is not enough (`marker.js` / `controls.js` errors, no draggable marker).

**Fix:** serve a local IE11-compatible Leaflet map (CyclOSM streets +
Esri satellite with labels, zoom up to 22) in place of the remote Google page, preserving the original
JS bridge (`window.external.*`), so track sync works again. The server
starts on demand with VIRB Edit (rewritten shortcuts launch a hidden
launcher first) and stops when it closes — no autostart task, no console windows.

**Install:** download the zip from Releases, run `install.bat` as admin,
restart VIRB Edit. **Uninstall:** run `uninstall.bat`.

## Лицензии стороннего кода

- [Leaflet 1.7.1](https://leafletjs.com/) — BSD 2-Clause (`files/www/.../javascript/leaflet/`)
- [jQuery 2.0.3](https://jquery.org/license/) — MIT (тот же файл, что раздаёт сам Garmin CDN)
- Картографические данные © [OpenStreetMap](https://www.openstreetmap.org/copyright),
  стиль [CyclOSM](https://www.cyclosm.org/),
  спутниковые снимки и подписи © Esri
- Оригинальные `TrackIntf.js` и иконки маркеров — Garmin
- Собственный код патча (`server.ps1`, `VirbEdit-Launcher.cs`, `Track.js`, установщик) — MIT (см. `LICENSE`)
