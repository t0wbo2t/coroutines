# Custom Coroutine Implementation in GNU Assembly

This repository contains a custom implementation of coroutines in GNU Assembly with AT&T syntax for Linux. The implementation demonstrates low-level context switching by manually managing the stack pointers (`rsp`), base pointers (`rbp`), and instruction pointers (`rip`) for each coroutine.

## Features

- **Pre-Allocated Stack Management:**
  - The stack memory for coroutines is pre-allocated in a static pool (`stack_pool`), divided into fixed-sized chunks.
  - Each coroutine is assigned a dedicated portion of the stack during creation.

- **Efficient Context Switching:**
  - Stores and restores the `rsp`, `rbp`, and `rip` for each coroutine.
  - Supports round-robin scheduling by iterating through available coroutines.

- **Simple Coroutine API:**
  - `coroutine_init`: Initializes the first coroutine.
  - `create_coroutine`: Creates a new coroutine and assigns it a portion of the pre-allocated stack.
  - `coroutine_yield`: Saves the current context and switches to the next coroutine.

## Limitations

1. **Static Stack Allocation:**
   - The stack memory is statically allocated at compile time.
   - The size and number of stacks are fixed by the constants `STACK_SIZE` and `COROUTINE_CAPACITY`.

2. **No Dynamic Stack Reclamation:**
   - Stacks assigned to finished coroutines remain allocated.

3. **Fixed Coroutine Capacity:**
   - The number of coroutines is limited to the value of `COROUTINE_CAPACITY`.

## How It Works

1. **Stack Management:**
   - Each coroutine has a pre-allocated stack segment. The `rsp` is set to the top of this segment when the coroutine is created.

2. **Context Switching:**
   - When a coroutine yields, its `rsp`, `rbp`, and `rip` are saved in a table indexed by its coroutine ID.
   - The next coroutine's saved context is restored, allowing it to resume execution from where it left off.

3. **Round-Robin Scheduling:**
   - Coroutines are scheduled in a simple round-robin manner.
   - When the last coroutine yields, the scheduler loops back to the first coroutine.

## Future Enhancements

- Implement dynamic stack allocation using `mmap` for runtime memory management.
- Add support for terminating coroutines and reclaiming their stack memory.
- Improve the scheduler to support priority-based or event-driven scheduling.

## Usage

To assemble and run the program:
```bash
as -o coroutines.o coroutines.s
ld -o coroutines coroutines.o
./coroutines
```

## License
This project is licensed under the GNU General Public License.

