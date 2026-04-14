---
name: aatex-cards
description: CRUD карточек в ЦУП ААТех — создание, обновление, перемещение, поиск, иерархия, архивация. Применяй для задач "создай задачу", "найди карточку", "обнови срок", "перенеси в колонку", "архивируй", "кто ответственный", "что в заказе". Для заказов (order type) используй специализированный aatex-orders.
---

# Работа с карточками

## Когда использовать

- Создание любых карточек (кроме order — используй `aatex-orders`)
- Поиск карточек по названию, пользователю, статусу
- Обновление полей: срок, ответственный, тип, описание, даты
- Перемещение между колонками/досками
- Работа с иерархией: родитель/дочерние, дерево
- Архивация / разархивация
- Массовые операции (bulk)

## Краткий каталог

| Инструмент | Параметры | Назначение |
|-----------|-----------|-----------|
| `create_card` | `boardId, spaceId, columnId, title, cardType?, ...` | Создать |
| `get_card` | `cardId` | **Полные** детали |
| `update_card` | `cardId, ...` | Обновить (null очищает) |
| `move_card` | `cardId, columnId, boardId, positionInColumn?` | Переместить |
| `search_cards` | `query, limit?` | Поиск по title (компактно) |
| `list_cards` | `boardId, columnId?, limit?, offset?` | Карточки доски (компактно) |
| `get_card_children` | `cardId` | Прямые дочерние |
| `get_card_tree` | `cardId` | Рекурсивное дерево |
| `get_card_history` | `cardId` | Аудит-лог |
| `archive_card` | `cardId, isArchived` | Архивация |
| `delete_card` | `cardId` | Soft-delete (== archive) |
| `bulk_move_cards` | `cardIds[], columnId, boardId` | Массовое перемещение |
| `assign_responsible` | `cardId, userId` | Назначить ответственного |
| `get_user_cards` | `userId, role?` | Карточки пользователя |

## Типы карточек

| Тип | Когда использовать |
|-----|-------------------|
| `position` | Позиция заказа (дочерняя) |
| `documentation` | Документация (под позицией) |
| `documentationSpecification` | Спецификация документации |
| `componentsToPurchase` | Покупное изделие |
| `product` | Изделие из каталога (требует `productAmount` + `productId`) |
| `order` | **Заказ** — используй скилл `aatex-orders` |
| `request` | Заявка с сайта (создаётся виджетом, не через MCP) |

## Сценарии

### 1. Создать простую карточку

```
1. list_all_boards → найти primary доску
2. get_board_columns(boardId) → получить columnId
3. list_users(search) → responsibleUserId (если нужно)
4. create_card(
     boardId, spaceId, columnId,
     title: "Название",
     cardType: "position",       // опционально
     description: "...",          // опционально
     responsibleUserId: "...",    // опционально
     userIds: ["uid1", "uid2"],   // участники
     productionEndDatePlanned: "YYYY-MM-DD"  // срок
   )
```

### 2. Создать подзадачу (карточка под другой)

```
1. get_card(parentId) → подтвердить контекст (boardId, spaceId)
2. get_board_columns(boardId) → columnId (часто та же, что у родителя)
3. create_card(
     boardId, spaceId, columnId, title,
     parentCardId: parentId,
     cardType: "position"  // или другой дочерний тип
   )
```

### 3. Найти и обновить

```
1. search_cards(query="текст из названия", limit: 20)
   → если много — уточни у пользователя
2. get_card(cardId) → показать полные детали
3. update_card(cardId, {
     title: "...",              // новое имя (или не передавать)
     description: "...",         // null — очистить
     responsibleUserId: "...",   // null — снять ответственного
     productionEndDatePlanned: "2026-05-01",
     // и т.д.
   })
```

**Правило:** `update_card` обновляет только переданные поля. `null` — очистить. Пропуск — не трогать.

### 4. Переместить карточку

```
1. get_card(cardId) → узнать текущую boardId (всегда primary)
2. (если другая доска) get_board_columns(targetBoardId) → targetColumnId
3. move_card(cardId, columnId, boardId, positionInColumn: 0)
```

**Важно:** даже если карточка отображается на dispatch-доске, её primary boardId не меняется. Перемещайте по primary — каскад на dispatch сработает сам.

### 5. Массовое перемещение

Например: «перенести все карточки Иванова в колонку "В работе"»

```
1. list_users(search="Иванов") → userId
2. get_user_cards(userId, role: "responsible") → массив cardIds
3. get_board_columns(boardId) → targetColumnId
4. bulk_move_cards(cardIds, columnId, boardId)
```

### 6. Работа с иерархией

```
# Что внутри заказа (только первый уровень):
get_card_children(orderCardId)

# Всё дерево (заказ → позиции → документация → изделия):
get_card_tree(orderCardId)
```

### 7. Аудит — кто что менял

```
get_card_history(cardId) → лог: создание, перемещение, смена ответственного, даты
```

### 8. Назначить ответственного (быстро)

```
1. list_users(search="...") → userId
2. assign_responsible(cardId, userId)
```

Это алиас для `update_card(cardId, {responsibleUserId: userId})`, но короче.

### 9. Архивация

```
# Архивировать (скрыть с доски):
archive_card(cardId, isArchived: true)
# или
delete_card(cardId)  // то же самое

# Восстановить:
archive_card(cardId, isArchived: false)
```

Карточки **никогда не удаляются физически** — только soft-archive. Их можно восстановить.

## Важные нюансы

### Компактные vs полные ответы

**Компактные** (id, title, cardType, column, responsible, dates): `list_cards`, `search_cards`, `get_card_children`, `get_card_tree`, `get_user_cards`.

Для **полных** данных (description, files, boardPositions, typeSpecificData, history) — всегда `get_card(cardId)`.

### Пагинация

`list_cards` — пагинация через `limit` (default 50, max 500) + `offset`. Проверяй `hasMore` в ответе.

### Продуктовые карточки

Для `cardType: "product"` обязательны:
- `productId` из `list_products`
- `productAmount >= 1`

```
1. list_products → productId
2. create_card(..., cardType: "product", productId, productAmount: 5)
```

### Даты

- Формат: **`YYYY-MM-DD`** (строка)
- Плановые: `productionStartDatePlanned`, `productionEndDatePlanned`
- Фактические: `productionStartDate`, `productionEndDate`
- Переопределение длительности: `customProductionDays` (integer)
- Учёт выходных: `list_holidays`

### Participants vs Responsible

- `responsibleUserId` — **один** ответственный
- `userIds` — массив **участников** (заменяет весь список при update)

Если надо добавить участника, сначала `get_card(cardId) → card.userIds`, потом `update_card(cardId, {userIds: [...old, newId]})`.

## Типичные ошибки

| Ошибка | Причина |
|--------|---------|
| `Cannot create card on dispatch board` | `boardId` — dispatch. Используй primary. |
| `productAmount required for product type` | Забыл `productAmount` при `cardType: "product"` |
| `Parent card not found` | `parentCardId` невалиден или карточка в другой орге |
| `Access denied` | Нет доступа к доске через `userIds` |
| Обновление не сработало, поле не изменилось | Zod отбросил неверное имя поля — проверь описание инструмента |
