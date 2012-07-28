#include "objc/track.h"
#include <objc/runtime.h>
#include "uthash.h"
#include <pthread.h>
#include <unistd.h>
#include <stdint.h>
#include <errno.h>

#define TRACK_LOG(prefix, format, ...) \
    RELEASE_LOG("%s " format, prefix, ##__VA_ARGS__)

#define TRACK_LOG_HEADER(prefix) \
    TRACK_LOG(prefix, ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
#define TRACK_LOG_FOOTER(prefix) \
    TRACK_LOG(prefix, "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<")

const size_t max_history_depth = 10;

typedef struct
{
    Class class;
    const char* class_name;
    int32_t count;
    UT_hash_handle hh;
} allocation_entry;

typedef struct
{
    Class class;
    const char* class_name;
    int32_t total_count;
    int32_t count_diffs[max_history_depth];
    BOOL non_zero;
    UT_hash_handle hh;
} history_entry;

static pthread_once_t lock_once = PTHREAD_ONCE_INIT;
static volatile pthread_mutex_t* lock = NULL;

static BOOL enabled = YES;

static size_t break_count = 0;
static Class break_class = NULL;

static allocation_entry* allocations = NULL;
static size_t total_allocation_count = 0;

static size_t snapshot_count = 0;
static allocation_entry* snapshot = NULL;
static history_entry* history = NULL;

/***** private functions *****/

static void track_lock_initializer(void)
{
    pthread_mutex_t* new_lock;
    pthread_mutexattr_t attr;
    int error = 0;

    new_lock = (pthread_mutex_t*)malloc(sizeof(pthread_mutex_t));
    if (!new_lock) error = ENOMEM;
    if (!error) error = pthread_mutexattr_init(&attr);
    if (!error) error = pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    if (!error) error = pthread_mutex_init(new_lock, &attr);

    if (error)
    {
        TRACK_LOG("TRACK-ERR", "Mutex creation failed with %d!", error);
        enabled = NO;
        DEBUG_BREAK();
    }
    else
    {
        lock = new_lock;
    }
}

static void track_lock(void)
{
    if (!lock)
    {
        pthread_once(&lock_once, track_lock_initializer);
    }
    if (lock)
    {
        pthread_mutex_lock((pthread_mutex_t*)lock);
    }
}

static void track_unlock(void)
{
    if (lock)
    {
        pthread_mutex_unlock((pthread_mutex_t*)lock);
    }
}

static void change_allocations_count(allocation_entry* entry, int32_t delta)
{
    entry->count += delta;
    total_allocation_count += delta;
    if (delta > 0)
    {
        if (break_count && (
            (!break_class && total_allocation_count >= break_count) ||
            (break_class == entry->class && entry->count >= break_count)))
        {
            track_breakpoint();
        }
    }
}

// Maintains descending order.
static int32_t compare_allocation_entries(allocation_entry* x, allocation_entry* y)
{
    if (x->count == y->count)
    {
        return 0;
    }
    else if (x->count > y->count)
    {
        return -1;
    }
    else
    {
        return +1;
    }
}

static void clear_allocation_entries(allocation_entry* entries)
{
    allocation_entry* entry = NULL;
    allocation_entry* entry_tmp = NULL;
    HASH_ITER(hh, entries, entry, entry_tmp)
    {
        entry->count = 0;
    }
}

static allocation_entry* find_allocation_entry(allocation_entry* entries, Class class)
{
    allocation_entry* entry = NULL;
    HASH_FIND_PTR(entries, &class, entry);
    return entry;
}

static allocation_entry* add_allocation_entry(allocation_entry** entries, Class class)
{
    allocation_entry* entry = (allocation_entry*)malloc(sizeof(allocation_entry));
    entry->class = class;
    entry->class_name = class_getName(class);
    entry->count = 0;
    HASH_ADD_PTR(*entries, class, entry);
    return entry;
}

static allocation_entry* get_allocation_entry(allocation_entry** entries, Class class)
{
    allocation_entry* entry = find_allocation_entry(*entries, class);
    if (!entry)
    {
        entry = add_allocation_entry(entries, class);
    }
    return entry;
}

static history_entry* get_history_entry(history_entry** entries, allocation_entry* allocation)
{
    history_entry* entry = NULL;
    HASH_FIND_PTR(*entries, &allocation->class, entry);
    if (!entry)
    {
        entry = (history_entry*)malloc(sizeof(history_entry));
        bzero(entry, sizeof(history_entry));
        entry->class = allocation->class;
        entry->class_name = allocation->class_name;
        HASH_ADD_PTR(*entries, class, entry);
    }
    return entry;
}

// Maintains descending order.
static int32_t compare_history_entries(history_entry* x, history_entry* y)
{
    if (x->total_count == y->total_count)
    {
        return 0;
    }
    else if (x->total_count > y->total_count)
    {
        return -1;
    }
    else
    {
        return +1;
    }
}

static size_t get_digit_count(int32_t value)
{
    if (value == INT32_MIN)
    {
        return 10;
    }
    if (value < 0)
    {
        value = -value;
    }
    if (value >= 1000000000) return 10;
    if (value >= 100000000 ) return 9;
    if (value >= 10000000  ) return 8;
    if (value >= 1000000   ) return 7;
    if (value >= 100000    ) return 6;
    if (value >= 10000     ) return 5;
    if (value >= 1000      ) return 4;
    if (value >= 100       ) return 3;
    if (value >= 10        ) return 2;
    else                     return 1;
}

static void update_max(unsigned int* max, unsigned int value)
{
    if (*max < value)
    {
        *max = value;
    }
}

/***** public interface *****/

void track_enable(void)
{
    track_lock();

    // Don't enable if there is no lock
    enabled = (lock != NULL);

    track_unlock();
}

void track_disable(void)
{
    track_lock();

    enabled = NO;

    track_unlock();
}

void track_breakpoint(void)
{
}

void track_break_on_allocations(size_t count, Class class)
{
    track_lock();

    break_count = count;
    break_class = class;

    track_unlock();
}

void track_allocation(Class class)
{
    track_lock();

    if (enabled)
    {
        allocation_entry* entry = get_allocation_entry(&allocations, class);
        change_allocations_count(entry, +1);
    }

    track_unlock();
}

void track_deallocation(Class class)
{
    track_lock();

    if (enabled)
    {
        allocation_entry *entry = find_allocation_entry(allocations, class);
        if (entry)
        {
            change_allocations_count(entry, -1);
        }
    }

    track_unlock();
}

void track_swizzle(Class from_class, Class to_class)
{
    track_lock();

    if (enabled)
    {
        allocation_entry* from_entry = find_allocation_entry(allocations, from_class);
        if (from_entry)
        {
            change_allocations_count(from_entry, -1);
        }

        allocation_entry* to_entry = get_allocation_entry(&allocations, to_class);
        change_allocations_count(to_entry, +1);
    }

    track_unlock();
}

void track_log(void)
{
    track_lock();

    const char* prefix = "TRACK-ALLOC";
    TRACK_LOG_HEADER(prefix);

    unsigned int class_name_width = 0;
    unsigned int count_width = 0;

    HASH_SORT(allocations, compare_allocation_entries);

    allocation_entry* entry = NULL;
    allocation_entry* entry_tmp = NULL;
    HASH_ITER(hh, allocations, entry, entry_tmp)
    {
        if (entry->count)
        {
            update_max(&class_name_width, strlen(entry->class_name));
            update_max(&count_width, get_digit_count(entry->count));
        }
    }
    HASH_ITER(hh, allocations, entry, entry_tmp)
    {
        if (entry->count)
        {
            TRACK_LOG(prefix, "%-*s: %*d",
                class_name_width, entry->class_name,
                count_width + 1, entry->count);
        }
    }

    TRACK_LOG_FOOTER(prefix);

    track_unlock();
}

void track_clear(void)
{
    track_lock();

    clear_allocation_entries(allocations);
    total_allocation_count = 0;

    track_clear_snapshots();

    track_unlock();
}

void track_snapshot(void)
{
    track_lock();

    // Widths of corresponding fields, used to get pretty output
    unsigned int class_name_width = 0;
    unsigned int totals_width = 0;
    unsigned int count_diff_widths[max_history_depth] = {0};

    allocation_entry* entry = NULL;
    allocation_entry* entry_tmp = NULL;
    HASH_ITER(hh, allocations, entry, entry_tmp)
    {
        allocation_entry* sentry = find_allocation_entry(snapshot, entry->class);
        if (entry->count == 0 && !sentry)
        {
            // No allocations and no snapshot entry - skip
            continue;
        }
        if (!sentry)
        {
            sentry = add_allocation_entry(&snapshot, entry->class);
        }

        if (snapshot_count) {
            // Record allocations diff. We can't generate diff when there is no
            // snapshots, so we skip this step for the first one.

            history_entry* hentry = get_history_entry(&history, entry);

            size_t diff_index = snapshot_count - 1;
            if (diff_index >= max_history_depth)
            {
                // Merge second diff to the first and shift history to make room
                // for the current diff.
                diff_index = max_history_depth - 1;
                hentry->count_diffs[0] += hentry->count_diffs[1];
                memmove(
                    hentry->count_diffs + 1,
                    hentry->count_diffs + 2,
                    (max_history_depth - 2) * sizeof(*hentry->count_diffs));
            }

            int32_t count_diff = (entry->count - sentry->count);
            if (count_diff)
            {
                hentry->non_zero = YES;
            }
            hentry->count_diffs[diff_index] = count_diff;
            hentry->total_count += count_diff;

            if (hentry->non_zero)
            {
                // Update widths
                update_max(&class_name_width, strlen(hentry->class_name));
                update_max(&totals_width, get_digit_count(hentry->total_count));
                for (size_t i = 0; i <= diff_index; ++i)
                {
                    update_max(count_diff_widths +i, get_digit_count(hentry->count_diffs[i]));
                }
            }
        }

        // Update snapshot entry
        sentry->count = entry->count;
    }

    if (snapshot_count)
    {
        const char* prefix = "TRACK-HIST";
        TRACK_LOG_HEADER(prefix);

        const char* cell_format      = " %+*d ";
        const char* zero_cell_format = " %*d ";
        const size_t max_cell_width = 15; // "| -2147483648 |"
        char row_buffer[max_history_depth * max_cell_width + 1];

        history_entry* hentry = NULL;
        history_entry* hentry_tmp = NULL;
        HASH_SORT(history, compare_history_entries);
        HASH_ITER(hh, history, hentry, hentry_tmp)
        {
            if (!hentry->non_zero)
            {
                continue;
            }
            char* row = row_buffer;
            for (size_t i = 0; i != snapshot_count && i != max_history_depth; ++i)
            {
                if (i)
                {
                    *row++ = '|';
                }
                int printed = snprintf(
                    row, sizeof(row_buffer) - (row - row_buffer),
                    (hentry->count_diffs[i] ? cell_format : zero_cell_format),
                    count_diff_widths[i] + 1, hentry->count_diffs[i]);
                if (printed > 0)
                {
                    row += printed;
                }
            }
            *row = '\0';
            TRACK_LOG(prefix, "%-*s: %*d [%s]",
                class_name_width, hentry->class_name,
                totals_width + 1, hentry->total_count,
                row_buffer);
        }

        TRACK_LOG_FOOTER(prefix);
    }

    snapshot_count += 1;

    track_unlock();
}

void track_clear_snapshots(void)
{
    track_lock();

    clear_allocation_entries(snapshot);

    history_entry* hentry = NULL;
    history_entry* hentry_tmp = NULL;
    HASH_ITER(hh, history, hentry, hentry_tmp)
    {
        hentry->total_count = 0;
        hentry->non_zero = NO;
    }

    snapshot_count = 0;

    track_unlock();
}
