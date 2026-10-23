# Анализ потоков данных (Def-Use)

Нумерация строк функции process_transaction:

python
1  def process_transaction(user_id, amount, db_connection):
2      log_entry = "Start processing"
3      if amount > 0:
4          status = "approved"
5          balance = get_balance(user_id)
6          new_balance = balance - amount
7          update_balance(user_id, new_balance)
8          log_entry = "Transaction finished with status: " + status
9      file = open("audit_log.txt", "w")
10     file.write(log_entry)
11     return status


## Цепочки Def-Use

Переменная: log_entry
- Def: строка 2 (log_entry = "Start processing")
- Def: строка 8 (log_entry = "Transaction finished ...", только при amount > 0)
- Use: строка 10 (file.write(log_entry)`)

Переменная: status
- Def: строка 4 (status = "approved", только при amount > 0)
- Use: строка 8 (использование в конкатенации строки)
- Use: строка 11 (return status)

Переменная: balance
- Def: строка 5 (balance = get_balance(user_id))
- Use: строка 6 (balance - amount)

Переменная: new_balance
- Def: строка 6 (new_balance = balance - amount)
- Use: строка 7 (аргумент update_balance)

Переменная: file
- Def: строка 9 (file = open(...))
- Use: строка 10 (file.write(...))
- Закрытия (file.close()) нет.

Параметры: user_id (use: строки 5, 7), amount (use: строки 3, 6),
db_connection (нигде не используется).

## Дефекты

1. **Неинициализированная переменная.** status определяется только внутри
   if amount > 0 (строка 4), а используется в строке 11 безусловно. При
   amount <= 0 ветка не выполняется и return status вызывает
   UnboundLocalError.
2. **Мертвое присваивание (Dead Store).** Значение "Start processing"
   (строка 2) при amount > 0 перезаписывается в строке 8 и ни разу не
   читается.
3. **Утечка ресурса.** Файл открывается в строке 9, но не закрывается
   (file.close() нет). При исключении в write дескриптор тоже не будет
   освобожден.
