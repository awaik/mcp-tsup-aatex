---
name: aatex-orders
description: Создание и управление заказами (order type) в ЦУП ААТех. Применяй когда пользователь говорит "создай заказ", "новый order", "договор с клиентом", "закупка от поставщика", "привяжи контрагента к заказу". Заказы ТРЕБУЮТ buyer и seller контрагентов — это специфика типа order, отличающаяся от обычных карточек.
---

# Создание заказов (order type)

## Когда использовать

Специализированный скилл для работы с карточками типа **`order`**. Используй его, а не общий `aatex-cards`, когда:

- Пользователь явно говорит «заказ», «договор», «order»
- Нужно привязать контрагентов (покупателя/продавца)
- Создаётся структура «заказ → позиции → документация»

## Что обязательно для заказа

| Поле | Источник |
|------|----------|
| `boardId` (primary) | `list_all_boards` или `list_boards` |
| `spaceId` | оттуда же |
| `columnId` | `get_board_columns(boardId)` |
| `title` | от пользователя |
| `cardType: "order"` | константа |
| `typeSpecificData.buyerContragentId` | `list_contragents(search="...")` |
| `typeSpecificData.sellerContragentId` | `list_contragents(search="...")` |

**КРИТИЧЕСКИ ВАЖНО:** без обоих контрагентов заказ создать нельзя — API вернёт ошибку.

## Полный пример создания заказа

### Шаг 1. Собрать контрагентов

```
# Ищем покупателя:
list_contragents(search="ООО Ромашка")
→ [{id: "cg_abc", name: "ООО Ромашка", inn: "7707..."}, ...]
→ buyerContragentId = "cg_abc"

# Если не нашли — создать:
search_contragent_by_inn(inn: "7707083893")  # данные из ЕГРЮЛ
create_contragent(name, inn, kpp, ogrn, legalAddress)
→ contragentId

# Ищем продавца (себя):
list_contragents(search="название своей орги")
→ sellerContragentId
```

### Шаг 2. Найти доску

```
list_all_boards
→ ищем спейс "Продажи" или "Заказы", тип primary
→ boardId, spaceId

get_board_columns(boardId)
→ находим колонку "Новые" или "Черновик"
→ columnId
```

### Шаг 3. Создать заказ

```
create_card({
  boardId,
  spaceId,
  columnId,
  title: "Заказ №15 — ООО Ромашка",
  cardType: "order",
  description: "...",                    // опционально
  responsibleUserId: "...",               // кто ведёт заказ
  typeSpecificData: {
    buyerContragentId,
    sellerContragentId,
    contractNumber: "15/2026",            // номер договора
    contractDate: "2026-04-15",           // дата (YYYY-MM-DD)
    contractLink: "https://...",          // опционально
    specificationNumber: "SP-001",        // опционально
    specificationDate: "2026-04-16",
    buyerContactPersonIndex: 0,           // индекс контакта в contragent.contacts
    sellerContactPersonIndex: 0,
  },
  productionStartDatePlanned: "2026-05-01",
  productionEndDatePlanned: "2026-06-30",
})
```

### Шаг 4. (Опционально) добавить позиции

```
# Для каждой позиции:
create_card({
  boardId, spaceId, columnId,
  title: "Позиция 1 — Продукт X",
  cardType: "position",
  parentCardId: orderCardId,           // привязка к заказу
  description: "...",
})
```

## typeSpecificData — поля для order

| Поле | Тип | Назначение |
|------|-----|------------|
| `buyerContragentId` | string | **Обязательно** — покупатель |
| `sellerContragentId` | string | **Обязательно** — продавец |
| `contractNumber` | string | Номер договора |
| `contractDate` | `YYYY-MM-DD` | Дата договора |
| `contractLink` | string | URL документа |
| `buyerContactPersonIndex` | number | Индекс контакта покупателя (0-based) |
| `buyerContactPersonIndexes` | number[] | Несколько контактов покупателя |
| `sellerContactPersonIndex` | number | Индекс контакта продавца |
| `sellerContactPersonIndexes` | number[] | Несколько контактов продавца |
| `specificationNumber` | string | Номер спецификации |
| `specificationDate` | `YYYY-MM-DD` | Дата спецификации |
| `specificationLink` | string | URL спецификации |

## Контактные лица

У контрагента в `contacts` — массив `[{name, phone, email, position}, ...]`. Индекс — позиция в этом массиве.

Чтобы привязать конкретное контактное лицо:

```
1. get_contragent(buyerContragentId) → contragent.contacts
2. Нашли нужного человека на индексе N
3. create_card(..., typeSpecificData: {..., buyerContactPersonIndex: N})
```

## Обновление существующего заказа

```
update_card(orderCardId, {
  typeSpecificData: {
    buyerContragentId: "новый_id",      // заменить покупателя
    contractNumber: "15-upd/2026",
  }
})
```

**Важно:** `typeSpecificData` в update — **merge**, а не replace. Только переданные поля меняются, остальные остаются.

Для полной очистки — `typeSpecificData: null`.

## Типичные ошибки

| Ошибка | Причина |
|--------|---------|
| `buyerContragentId and sellerContragentId are required for order type` | Забыл контрагентов в typeSpecificData |
| `Contragent not found` | ID неправильный или контрагент в другой орге |
| `Invalid date format` | Дата не в `YYYY-MM-DD` |
| Заказ создан, но тип не order | Забыл `cardType: "order"` |
| `Cannot create card on dispatch board` | Используется dispatch вместо primary |

## Связь с другими скиллами

- **`aatex-contragents`** — поиск, создание контрагентов, ЕГРЮЛ
- **`aatex-navigation`** — найти подходящую доску и колонку
- **`aatex-cards`** — после создания заказа, работа с позициями
- **`aatex-files`** — прикрепить скан договора к карточке заказа

## Пример полного диалога

Пользователь: *«Создай заказ №42 для ООО Авангард, договор 42/2026 от 15 апреля»*

```
1. list_contragents(search="Авангард") → cg_buyer_id
2. list_contragents(search="<своя орга>") → cg_seller_id
3. list_all_boards → boardId="...", spaceId="..." (доска Продажи, primary)
4. get_board_columns(boardId) → columnId="col_new"
5. create_card({
     boardId, spaceId, columnId,
     title: "Заказ №42 — ООО Авангард",
     cardType: "order",
     typeSpecificData: {
       buyerContragentId: "cg_buyer_id",
       sellerContragentId: "cg_seller_id",
       contractNumber: "42/2026",
       contractDate: "2026-04-15"
     }
   })
   → заказ создан, показать id
```
