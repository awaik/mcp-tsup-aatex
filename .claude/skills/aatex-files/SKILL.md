---
name: aatex-files
description: Загрузка и управление файлами в ЦУП ААТех. Применяй для "прикрепи файл", "загрузи скан", "покажи вложения карточки", "скачай файл", "удали вложение". Поддерживает файлы на карточках, комментариях, сообщениях через base64 (лимит 20 МБ).
---

# Файлы и вложения

## Когда использовать

- Прикрепить файл к карточке (скан договора, чертёж, фото)
- Приложить файл к комментарию или сообщению
- Получить список файлов карточки
- Скачать файл (presigned URL)
- Удалить вложение

## Три типа вложений

| Тип | Куда прикрепляется | Как загружать |
|-----|-------------------|---------------|
| **Card attachment** | Файл карточки | `upload_card_file` (сразу привязывается) |
| **Comment attachment** | Файл комментария | `upload_comment_file` → `create_card_comment` |
| **Message attachment** | Файл сообщения | `upload_message_file` → `send_message` |

## Инструменты

| Инструмент | Параметры | Назначение |
|-----------|-----------|-----------|
| `upload_card_file` | `cardId, fileName, mimeType, base64Content` | Загрузить в карточку (сразу) |
| `upload_comment_file` | `cardId, fileName, mimeType, base64Content` | Загрузить для комментария → attachmentId |
| `upload_message_file` | `conversationId, fileName, mimeType, base64Content` | Загрузить для сообщения → attachmentId |
| `list_card_attachments` | `cardId` | Список файлов карточки |
| `get_attachment_url` | `attachmentId` | Presigned download URL (1 час) |
| `delete_attachment` | `attachmentId` | Удалить (только загрузивший) |

## Сценарии

### 1. Прикрепить файл к карточке (прямая загрузка)

```python
# Псевдокод — адаптируй под свою среду:
# 1. Прочитать файл локально
content_bytes = read_file("contract.pdf")
# 2. Закодировать в base64
b64 = base64_encode(content_bytes)
# 3. Загрузить:
upload_card_file(
  cardId: 12345,
  fileName: "contract.pdf",
  mimeType: "application/pdf",
  base64Content: b64
)
# → файл сразу появится в карточке
```

**Готово за один шаг** — в отличие от комментариев/сообщений, для карточек не нужен второй вызов.

### 2. Комментарий с файлом (два шага)

```
1. upload_comment_file(
     cardId: 12345,
     fileName: "report.docx",
     mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
     base64Content: "<base64>"
   )
   → { attachmentId: "att_abc" }

2. create_card_comment(
     cardId: 12345,
     content: "Отчёт прикрепил",
     attachmentIds: ["att_abc"]
   )
```

### 3. Сообщение с файлом

```
1. upload_message_file(
     conversationId: "conv_xyz",
     fileName: "scan.png",
     mimeType: "image/png",
     base64Content: "<base64>"
   )
   → { attachmentId: "att_def" }

2. send_message(
     conversationId: "conv_xyz",
     content: "Скан:",
     attachmentIds: ["att_def"]
   )
```

### 4. Показать файлы карточки

```
list_card_attachments(cardId)
→ [
    {
      id, fileName, fileSize, mimeType,
      attachmentType,  // 'card' | 'comment' | 'message'
      uploadedBy,
      createdAt
    }, ...
  ]
```

### 5. Скачать файл

```
get_attachment_url(attachmentId)
→ {
    url: "https://...",           // presigned, TTL 1 час
    fileName, mimeType, fileSize,
    thumbnailUrl?,                 // для изображений
    width?, height?                // для изображений
  }
```

URL действителен **1 час**. Если файл большой — сразу скачивайте, не храните URL надолго.

Работает для **всех** типов (card/comment/message).

### 6. Удалить файл

```
delete_attachment(attachmentId)
```

**Только загрузивший может удалить.** Если файл чужой — будет `Access denied`.

Для card attachment: автоматически декрементится счётчик файлов карточки.

## Важные нюансы

### Лимит размера

**Максимум ~20 МБ** на файл. Это жёсткий лимит MCP transport (base64 раздувает размер в ~1.33x, плюс JSON overhead).

Если файл больше — два варианта:
1. Пользователь загружает через UI (браузер использует multipart upload, лимит выше)
2. Разбей файл на части вне MCP и загрузи как несколько

### Base64 encoding

- Клиент должен **сам кодировать** байты в base64 перед вызовом
- Не передавайте бинарные данные напрямую — только base64 string
- Empty или invalid base64 → `base64Content is not valid base64`

### MIME types

Частые MIME-типы:
```
PDF:   application/pdf
DOCX:  application/vnd.openxmlformats-officedocument.wordprocessingml.document
XLSX:  application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
PNG:   image/png
JPG:   image/jpeg
ZIP:   application/zip
TXT:   text/plain
```

Если не знаешь — `application/octet-stream` (универсальный, браузер предложит скачать).

### Хранилище

Файлы идут в **MinIO** (S3-совместимое) по пути `{orgId}/{uuid}.{ext}`. Не доступны напрямую — только через presigned URL (`get_attachment_url`).

### Счётчик файлов карточки

При `upload_card_file` инкрементится `card.attachmentsCount`. При `delete_attachment` — декрементится. UI использует счётчик для отображения иконки без запроса списка.

### Thumbnails

Для изображений (image/*) автоматически генерируются thumbnails. `get_attachment_url` возвращает `thumbnailUrl` + размеры.

## Типичные ошибки

| Ошибка | Причина |
|--------|---------|
| `File too large: XMB (max 20MB)` | Файл больше 20 МБ |
| `base64Content is not valid base64` | Некорректная строка или пустая |
| `Access denied` | Не ваш файл (удаление) или нет доступа к карточке |
| `Card not found` | Неправильный `cardId` |
| `Unsupported mime type` | Некоторые типы могут быть заблокированы политикой (exe, etc.) |

## Связь с другими скиллами

- **`aatex-cards`** — загрузка файла на карточку
- **`aatex-messenger`** — файлы в сообщениях
- **`aatex-orders`** — прикрепить скан договора к карточке заказа

## Пример диалога

Пользователь: *«Прикрепи файл scan.pdf к карточке с ID 12345»*

```
# Предполагаем, что файл доступен локально
1. Прочитать scan.pdf в байты
2. base64_encode → b64
3. upload_card_file(
     cardId: 12345,
     fileName: "scan.pdf",
     mimeType: "application/pdf",
     base64Content: b64
   )
   → { id: "att_xyz", fileName: "scan.pdf", fileSize: 245678, ... }
4. Показать пользователю: "Файл scan.pdf (240 KB) загружен в карточку"
```

## Совет по UX

Перед загрузкой большого файла — **сообщи пользователю**:

> Файл `contract.pdf` размером 15 МБ. Загружаю (это может занять несколько секунд)...

После загрузки:

> Загружено ✓ Файл "contract.pdf" теперь в карточке #12345. [ссылка на get_attachment_url если нужно]
