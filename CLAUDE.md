# ЦУП ААТех — MCP для AI-ассистентов

Этот проект настроен для работы с **ЦУП ААТех** (Центр Управления Производством) через MCP (Model Context Protocol). AI-ассистент (Claude Desktop, Claude Code, Cursor, VS Code) получает те же права, что и пользователь в веб-интерфейсе: управляет заказами, карточками, контрагентами, мессенджером и файлами в вашей организации.

## Что такое ЦУП ААТех

Система управления проектами и производством для команд. Ключевые сущности:

- **Пространство (Space)** — рабочая область, объединяет доски по теме (Продажи, Производство и т.п.)
- **Доска (Board)** — канбан-доска с колонками. Типы: `primary` (карточки создаются здесь), `dispatch` (отображение из primary через каскад), `personal`
- **Колонка (Column)** — столбец доски, хранится в `board.columns` (JSONB). Может иметь `attachedBoardId` — дочернюю dispatch-доску
- **Карточка (Card)** — единица работы. Типы: `order` (заказ), `position` (позиция), `documentation`, `documentationSpecification`, `componentsToPurchase`, `product`, `request`
- **Контрагент (Contragent)** — внешний партнёр (клиент, поставщик). Реквизиты, ИНН, контактные лица, банк
- **Пользователь (User)** — сотрудник с ролью: `owner`, `admin`, `manager`, `member`, `viewer`, `client`

**Иерархия карточек:** Заказ → Позиция → (Документация | Спецификация | Покупное изделие | Изделие).

---

## Настройка MCP-клиента

### 1. Получить ключ доступа

1. Откройте https://app.aatex.ru и войдите в свою организацию
2. **Профиль → Подключить ИИ (MCP)**
3. Нажмите **«Создать ключ»** — он показывается **только один раз**, сразу скопируйте
4. Ключ привязан к вашему аккаунту и организации, даёт те же права, что и в UI

Ключ выглядит как 64 hex-символа, например: `a3f2...ce91`.

### 2. Сконфигурировать AI-клиента

**Если клонировали этот репозиторий** (рекомендуется):

```bash
cp .mcp.json.example .mcp.json
# откройте .mcp.json и замените ВАШ_КЛЮЧ на ключ из шага 1
```

Файл `.mcp.json` добавлен в `.gitignore` — ваш реальный ключ никогда не попадёт в коммиты и не уйдёт в релизные архивы.

**Если настраиваете вручную** (Claude Code / Claude Desktop) — добавьте в `.mcp.json` (в корне проекта) или `~/.claude.json`:

```json
{
  "mcpServers": {
    "aatex-cup": {
      "type": "http",
      "url": "https://app.aatex.ru/mcp",
      "headers": {
        "Authorization": "Bearer ВАШ_КЛЮЧ"
      }
    }
  }
}
```

**Cursor / VS Code** — аналогично, через настройки MCP серверов.

### 3. Проверить подключение

После перезапуска клиента должны появиться инструменты `mcp__aatex-cup__*` (57 штук). Попросите: **«Покажи пространства»** — вызовется `list_spaces`.

---

## Инструменты (57)

### Навигация и доски (6)

| Инструмент | Назначение |
|-----------|-----------|
| `list_spaces` | Пространства в организации |
| `list_boards(spaceId)` | Доски в пространстве |
| `get_board_columns(boardId)` | Колонки доски с типовыми ограничениями |
| `list_all_boards` | Все доски одним запросом (id, title, type, space) |
| `archive_board(boardId)` | Архивировать (soft-delete), только без активных карточек |
| `delete_board(boardId)` | Алиас для `archive_board` |

### Карточки (15)

| Инструмент | Назначение |
|-----------|-----------|
| `list_cards(boardId, columnId?, limit?, offset?, includeArchived?)` | Карточки доски (**компактно**, пагинация, default 50, max 500) |
| `get_card(cardId)` | **Полные** детали (description, files, boardPositions, typeSpecificData) |
| `create_card(boardId, spaceId, columnId, title, cardType?, ...)` | Создать. Только на primary досках |
| `update_card(cardId, ...)` | Обновить (null очищает поле) |
| `delete_card(cardId)` | Удалить (soft-archive) |
| `move_card(cardId, columnId, boardId, positionInColumn?)` | Переместить в другую колонку/доску |
| `search_cards(query, limit?)` | Поиск по названию (компактно) |
| `get_card_children(cardId)` | Прямые дочерние (один уровень вниз) |
| `get_card_tree(cardId)` | Всё дерево потомков рекурсивно |
| `get_card_history(cardId)` | Аудит-лог карточки |
| `archive_card(cardId, isArchived)` | Архивация / разархивация |
| `bulk_move_cards(cardIds, columnId, boardId)` | Массовое перемещение |
| `assign_responsible(cardId, userId)` | Назначить ответственного |
| `get_user_cards(userId, role?)` | Все карточки пользователя (responsible / participant) |

### Аналитика (3)

| Инструмент | Назначение |
|-----------|-----------|
| `get_board_summary(boardId)` | Сводка: счётчики по колонкам, без ответственного, в финальной колонке, просроченные |
| `get_overdue_cards(boardId, limit?)` | Просроченные (плановая дата окончания в прошлом, не в финальной) |
| `get_team_workload(boardId)` | Загрузка команды по людям и типам карточек |

### Комментарии (2)

| Инструмент | Назначение |
|-----------|-----------|
| `list_card_comments(cardId)` | Комментарии карточки |
| `create_card_comment(cardId, content, attachmentIds?)` | Добавить (+ socket + history + уведомления) |

### Мессенджер (7)

| Инструмент | Назначение |
|-----------|-----------|
| `list_conversations(type?)` | Беседы (`dm` / `group_dm` / `channel` / `saved`) |
| `list_messages(conversationId, limit?, before?)` | Сообщения с курсорной пагинацией |
| `send_message(conversationId, content, attachmentIds?)` | Отправить (socket + push) |
| `create_conversation(type, ...)` | Создать чат (dm: `targetUserId`; group_dm: `userIds`+`name`; channel: `name`) |
| `get_unread_summary` | Сводка непрочитанных по всем чатам |
| `add_conversation_participants(conversationId, userIds)` | Добавить участников в группу/канал |
| `search_messages(query, conversationId?, limit?)` | Поиск по тексту сообщений |

### Файлы (6)

| Инструмент | Назначение |
|-----------|-----------|
| `upload_card_file(cardId, fileName, mimeType, base64Content)` | Загрузить файл в карточку |
| `upload_comment_file(cardId, ...)` | Загрузить для комментария → `attachmentId` |
| `upload_message_file(conversationId, ...)` | Загрузить для сообщения → `attachmentId` |
| `list_card_attachments(cardId)` | Список файлов карточки |
| `get_attachment_url(attachmentId)` | Presigned download URL (TTL 1 час) |
| `delete_attachment(attachmentId)` | Удалить (только загрузивший) |

**Лимит:** ~20 МБ на файл, контент передаётся в base64.

### Контрагенты / CRM (5)

| Инструмент | Назначение |
|-----------|-----------|
| `list_contragents(search?)` | Список (поиск по имени/ИНН) |
| `get_contragent(contragentId)` | Детали: реквизиты, контакты, банк, адреса |
| `create_contragent(name, inn, kpp?, ogrn?, shortName?, legalAddress?)` | Создать |
| `update_contragent(contragentId, ...)` | Обновить |
| `search_contragent_by_inn(inn)` | Поиск в ЕГРЮЛ (только российские 10/12-значные ИНН) |

### Пользователи (2)

| Инструмент | Назначение |
|-----------|-----------|
| `list_users(search?)` | Пользователи организации (поиск по имени/email) |
| `get_user(userId)` | Детали пользователя |

### Организация (7)

| Инструмент | Назначение |
|-----------|-----------|
| `list_members(includeInactive?)` | Участники с ролями |
| `invite_member(email, role)` | Пригласить (**admin/owner only**) |
| `change_member_role(memberId, role)` | Сменить роль (**admin/owner only**) |
| `deactivate_member(memberId)` | Деактивировать (**admin/owner only**) |
| `list_invites` | Ожидающие приглашения |
| `list_properties` | Свойства — цветные лейблы для карточек |
| `list_holidays` | Производственные выходные |

### Продукция (2)

| Инструмент | Назначение |
|-----------|-----------|
| `list_products` | Каталог продукции |
| `get_product(productId)` | Детали изделия |

### Уведомления (3)

| Инструмент | Назначение |
|-----------|-----------|
| `get_notifications(isRead?, category?, limit?, cursor?)` | Список уведомлений |
| `get_unread_count` | Количество непрочитанных |
| `mark_notifications_read(notificationId?)` | Отметить прочитанными (одно или все) |

---

## Типичные сценарии

### Создать карточку (самое частое)

```
1. list_spaces                        → spaceId
2. list_boards(spaceId)               → boardId (тип primary)
3. get_board_columns(boardId)         → columnId + ограничения по типам
4. create_card(boardId, spaceId, columnId, title, cardType?, ...)
```

### Создать заказ (order)

```
1. list_contragents(search="заказчик")    → buyerContragentId
2. list_contragents(search="исполнитель") → sellerContragentId
3. list_spaces → list_boards → get_board_columns → boardId, spaceId, columnId
4. create_card(
     boardId, spaceId, columnId,
     title: "Заказ №...",
     cardType: "order",
     typeSpecificData: {
       buyerContragentId,
       sellerContragentId,
       contractNumber: "...",
       contractDate: "2026-04-15"
     }
   )
```

**Для order типа `buyerContragentId` и `sellerContragentId` в `typeSpecificData` — ОБЯЗАТЕЛЬНЫ.**

### Привязать подзадачу (позиция под заказом)

```
1. get_card(orderId)                   → убедиться что это order
2. get_board_columns(boardId)          → columnId (для подзадачи)
3. create_card(
     boardId, spaceId, columnId,
     title: "Позиция 1",
     cardType: "position",
     parentCardId: orderId
   )
```

### Переместить карточку

```
1. get_card(cardId)                    → текущая колонка/доска
2. get_board_columns(targetBoardId)    → целевая colId
3. move_card(cardId, columnId, boardId, positionInColumn: 0)
```

### Найти и обновить

```
1. search_cards(query="Договор 15")    → cardId
2. get_card(cardId)                    → полные данные
3. update_card(cardId, {
     responsibleUserId: "...",
     productionEndDatePlanned: "2026-04-30"
   })
```

### Аналитика по доске

```
1. get_board_summary(boardId)          → счётчики, стейт
2. get_overdue_cards(boardId)          → просроченные
3. get_team_workload(boardId)          → кто перегружен
```

### Прикрепить файл к карточке

```
# Читаете файл, кодируете в base64, вызываете:
upload_card_file(cardId, fileName, mimeType, base64Content)
```

### Комментарий с файлом

```
1. upload_comment_file(cardId, fileName, mimeType, base64Content) → attachmentId
2. create_card_comment(cardId, content, attachmentIds: [attachmentId])
```

### Создать контрагента из ЕГРЮЛ

```
1. search_contragent_by_inn(inn: "7707083893")   → данные из реестра
2. create_contragent(name, inn, kpp, ogrn, legalAddress)
```

---

## Важные особенности

### Типы карточек

| Тип | Цвет | Обязательные поля |
|-----|------|-------------------|
| `order` | `#A7C8FF` | `typeSpecificData.buyerContragentId` + `sellerContragentId` |
| `position` | `#FFC692` | Обычно `parentCardId` от order |
| `documentation` | `#E476FF` | — |
| `documentationSpecification` | `#FF9E78` | — |
| `componentsToPurchase` | `#7AFFCD` | — |
| `product` | `#FFF000` | `productAmount >= 1`, `productId` из каталога |
| `request` | `#64B5F6` | Создаётся автоматически через виджет с сайта |

### Primary vs Dispatch доски

- **Primary** — карточки создаются **ТОЛЬКО** здесь. `card.boardId` указывает на primary.
- **Dispatch** — отображает карточки из primary через каскад: колонка primary с `attachedBoardId` автоматически копирует позиции на связанную dispatch-доску при перемещении.
- **НИКОГДА** не создавайте карточки на dispatch-досках — используйте primary, каскад сработает сам.

### Компактные vs полные ответы

`list_cards`, `search_cards`, `get_card_children`, `get_card_tree`, `get_user_cards` — возвращают **компактные** записи (id, title, cardType, column, responsible, dates). Для полных данных (description, files, boardPositions, typeSpecificData) — `get_card(cardId)`.

### Даты

- Плановые: `productionStartDatePlanned`, `productionEndDatePlanned` (формат `YYYY-MM-DD`)
- Фактические: `productionStartDate`, `productionEndDate`
- Переопределение длительности: `customProductionDays`
- Учитываются `list_holidays` (производственные выходные)

### Доступ и права

- MCP-ключ даёт точно те же права, что и в UI (RBAC atomic permissions)
- `viewer` не сможет создавать карточки через MCP
- Доски с `userIds` фильтруются — недоступное не видно
- Все операции изолированы по `organizationId` — ключ привязан к одной организации

### Именование полей

Инструменты используют строгую Zod-валидацию: **неизвестные поля молча отбрасываются**. Если не сработало — проверьте точное имя параметра в описании инструмента.

---

## Безопасность

- **Ключ = полный доступ** — не делитесь, не публикуйте в git (добавьте `.mcp.json` в `.gitignore`)
- **При компрометации** отзовите ключ на странице «Подключить ИИ» и создайте новый
- **Отзыв через logout** — когда вы выходите из UI, `tokenVersion` инкрементится, но API-ключи продолжают работать (их надо отзывать явно)
- Все запросы идут через HTTPS

---

## Troubleshooting

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `401 Unauthorized` | Неправильный или отозванный ключ | Перегенерируйте на странице MCP |
| `Not a member of this organization` | Ключ от чужой организации | Создайте ключ в нужной орге |
| `403 Session belongs to another user` | Сессия чужая (после смены ключа) | Перезапустите AI-клиента |
| `Access denied` | Роль не разрешает действие (viewer и т.п.) | Попросите admin изменить роль |
| Инструмент молча игнорирует поле | Zod отбросил неизвестное имя | Проверьте точное имя параметра |
| `File too large (max 20MB)` | Лимит MCP-загрузок | Используйте UI или разбейте файл |
| Нет инструментов `mcp__aatex-cup__*` | Клиент не перезапущен / конфиг не подхвачен | Перезапустите клиента |

---

## Скиллы проекта

В `.claude/skills/` настроены специализированные скиллы. Claude подгрузит их автоматически по контексту задачи:

- **aatex-setup** — первая настройка, проверка подключения, ключи
- **aatex-navigation** — пространства, доски, колонки, ограничения
- **aatex-cards** — CRUD карточек, поиск, иерархия, дерево подзадач
- **aatex-orders** — создание заказов с контрагентами и позициями
- **aatex-contragents** — CRM, ЕГРЮЛ, реквизиты
- **aatex-analytics** — сводки, просроченные, загрузка команды
- **aatex-messenger** — чаты, сообщения, файлы
- **aatex-files** — загрузка и управление вложениями

---

## Ссылки

- **Веб-интерфейс:** https://app.aatex.ru
- **MCP endpoint:** `https://app.aatex.ru/mcp`
- **Страница ключей:** `https://app.aatex.ru/org/{slug}/profile/mcp`
- **Поддержка:** support@aatex.ru

---

**Версия:** 1.0
**MCP Server:** 1.0.0 · 57 tools
