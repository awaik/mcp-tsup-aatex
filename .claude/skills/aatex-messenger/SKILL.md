---
name: aatex-messenger
description: Мессенджер ЦУП ААТех — чаты, сообщения, каналы. Применяй для "отправь сообщение", "напиши в чат", "прочитай чат", "сколько непрочитанных", "создай канал", "добавь в группу", "поиск по переписке". Поддерживает DM, группы, каналы, файлы через upload_message_file.
---

# Мессенджер ЦУП ААТех

## Когда использовать

- Отправить сообщение пользователю или в группу/канал
- Прочитать историю чата
- Создать новый чат
- Проверить непрочитанные
- Искать по тексту сообщений
- Добавить людей в группу/канал
- Прикрепить файл к сообщению

## Типы бесед

| Тип | Участники | Когда использовать |
|-----|-----------|-------------------|
| `dm` | 2 (личка) | Один на один |
| `group_dm` | 3+ (приватная группа) | Рабочая группа |
| `channel` | Много (публично в орге) | Обсуждения, темы, объявления |
| `saved` | 1 (только вы) | Заметки себе |

## Инструменты

| Инструмент | Параметры | Назначение |
|-----------|-----------|-----------|
| `list_conversations` | `type?` | Беседы (фильтр по типу) |
| `list_messages` | `conversationId, limit?, before?` | История (курсорная пагинация) |
| `send_message` | `conversationId, content, attachmentIds?` | Отправить |
| `create_conversation` | `type, targetUserId?\|userIds?\|name, ...` | Создать чат |
| `get_unread_summary` | — | Сводка непрочитанных по всем |
| `add_conversation_participants` | `conversationId, userIds` | Добавить людей |
| `search_messages` | `query, conversationId?, limit?` | Поиск по тексту |

## Сценарии

### 1. Написать сообщение конкретному человеку (DM)

```
1. list_users(search="Иван") → userId = "uid_abc"
2. list_conversations(type: "dm") → проверь, есть ли уже DM
   # DM найти можно по type="dm" и одному из участников

3a. Если DM есть:
    send_message(conversationId, content)

3b. Если DM нет:
    create_conversation(type: "dm", targetUserId: "uid_abc") → conversationId
    send_message(conversationId, content)
```

**Оптимизация:** `create_conversation(type: "dm")` **идемпотентен** — если DM уже существует, вернёт существующую. Можно смело вызывать.

### 2. Создать групповой чат

```
1. list_users(search="...") → несколько userIds
2. create_conversation(
     type: "group_dm",
     userIds: ["uid1", "uid2", "uid3"],
     name: "Проект X - команда"
   )
   → conversationId
3. send_message(conversationId, "Привет, команда!")
```

### 3. Создать канал

```
create_conversation(
  type: "channel",
  name: "production-news",
  description: "Новости производства",
  isPrivate: false,       // true — только по приглашению
  userIds: ["..."]         // начальные участники (optional)
)
```

### 4. Прочитать последние сообщения

```
list_messages(conversationId, limit: 50)
→ массив сообщений (новые сверху)
```

### 5. Пагинация — более старые

```
# Первая страница:
list_messages(conversationId, limit: 50)
→ последнее сообщение id = "msg_xxx"

# Следующая (ещё старее):
list_messages(conversationId, limit: 50, before: "msg_xxx")
```

### 6. Сводка непрочитанных

```
get_unread_summary
```

Возвращает:
```json
{
  "totalUnread": 17,
  "conversations": [
    {"conversationId": "...", "name": "Проект X", "type": "group_dm", "unreadCount": 8},
    ...
  ]
}
```

Отсортировано по `unreadCount` убыв. — первые самые «горящие».

### 7. Поиск по тексту

```
search_messages(query: "договор", limit: 20)
→ массив сообщений из всех чатов, где вы участник
```

Ограничить поиск одним чатом:

```
search_messages(query: "срок", conversationId: "...")
```

### 8. Добавить участников в группу

```
add_conversation_participants(
  conversationId: "...",
  userIds: ["uid1", "uid2"]
)
```

Работает для `group_dm` и `channel`. Для `dm` нельзя — только 2 участника.

### 9. Отправить с файлом

```
1. Прочитать файл локально и закодировать в base64
2. upload_message_file(
     conversationId,
     fileName: "contract.pdf",
     mimeType: "application/pdf",
     base64Content: "<base64>"
   ) → attachmentId
3. send_message(
     conversationId,
     content: "Вот договор",
     attachmentIds: [attachmentId]
   )
```

**Лимит:** ~20 МБ на файл.

## Важные нюансы

### Socket.io + push

`send_message` автоматически:
1. Создаёт сообщение в БД
2. Эмитит socket event в комнату беседы
3. Отправляет push-уведомления участникам (fire-and-forget)

Сообщение **сразу видно** всем участникам в UI в реальном времени.

### Типы сообщений

`message.type`:
- `text` — обычное
- `file` — с прикреплёнными файлами (ставится автоматически при `attachmentIds`)
- `system` — системное (создание чата, добавление участников)
- `bot` — от бота
- `call` — звонок (метаданные в `metadata`)

Через MCP отправляются только `text` и `file`.

### Непрочитанные

MCP не отмечает сообщения как прочитанные автоматически. Если прочитал через `list_messages` — счётчик не изменится. Для отметки прочитанным — только UI.

### Поиск — ilike по содержимому

`search_messages` использует `ILIKE '%query%'` по `messages.content`. Не fuzzy, не морфология — точное вхождение. Для русского может потребоваться попробовать разные формы слова.

### Права доступа к беседам

- `dm`, `group_dm` — видны только участникам
- `channel public` — все в орге
- `channel private` — только приглашённые
- Все операции проверяют `conversationMembers`

## Типичные ошибки

| Ошибка | Причина |
|--------|---------|
| `targetUserId is required for dm type` | Забыл `targetUserId` в create_conversation для dm |
| `userIds is required for group_dm type` | Забыл `userIds` для group_dm |
| `name is required for channel type` | Забыл `name` для канала |
| `You are not a member of this conversation` | Нет доступа к беседе |
| `File too large` | > 20 МБ в `upload_message_file` |

## Связь с другими скиллами

- **`aatex-files`** — работа с файлами в сообщениях
- **`aatex-cards`** — `list_users` для поиска получателя (тот же инструмент)

## Пример диалога

Пользователь: *«Напиши Петру в личку, что заказ №42 готов»*

```
1. list_users(search="Пётр")
   → [{id: "uid_petr", name: "Пётр Петров"}, ...]
2. create_conversation(type: "dm", targetUserId: "uid_petr")
   → { id: "conv_abc", type: "dm", ... }  (или существующая)
3. send_message(
     conversationId: "conv_abc",
     content: "Пётр, заказ №42 готов ✓"
   )
   → отправлено
```
