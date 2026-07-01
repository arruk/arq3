#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <inttypes.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define DEFAULT_THREADS 2
#define DEFAULT_SAMPLES 10000000ULL

struct worker_args {
    uint64_t samples;
    uint64_t seed;
    uint64_t inside;
};

static uint64_t splitmix64(uint64_t *state)
{
    uint64_t z;

    *state += UINT64_C(0x9e3779b97f4a7c15);
    z = *state;
    z = (z ^ (z >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)) * UINT64_C(0x94d049bb133111eb);
    return z ^ (z >> 31);
}

static double random_unit(uint64_t *state)
{
    const double scale = 1.0 / 9007199254740992.0;

    return (double)(splitmix64(state) >> 11) * scale;
}

static void *monte_carlo_worker(void *arg)
{
    struct worker_args *worker = arg;
    uint64_t state = worker->seed;
    uint64_t inside = 0;

    for (uint64_t i = 0; i < worker->samples; i++) {
        double x = random_unit(&state);
        double y = random_unit(&state);

        if ((x * x + y * y) <= 1.0) {
            inside++;
        }
    }

    worker->inside = inside;
    return NULL;
}

static int parse_u64(const char *text, uint64_t *value)
{
    char *end = NULL;
    unsigned long long parsed;

    errno = 0;
    parsed = strtoull(text, &end, 10);
    if (errno != 0 || end == text || *end != '\0') {
        return -1;
    }

    *value = (uint64_t)parsed;
    return 0;
}

static double elapsed_seconds(const struct timespec *start,
                              const struct timespec *end)
{
    time_t seconds = end->tv_sec - start->tv_sec;
    long nanoseconds = end->tv_nsec - start->tv_nsec;

    if (nanoseconds < 0) {
        seconds--;
        nanoseconds += 1000000000L;
    }

    return (double)seconds + (double)nanoseconds / 1000000000.0;
}

static void usage(const char *program)
{
    fprintf(stderr, "Uso: %s [amostras] [threads]\n", program);
    fprintf(stderr, "Padrao: %" PRIu64 " amostras, %d threads\n",
            (uint64_t)DEFAULT_SAMPLES, DEFAULT_THREADS);
}

int main(int argc, char **argv)
{
    uint64_t total_samples = DEFAULT_SAMPLES;
    uint64_t thread_count = DEFAULT_THREADS;
    pthread_t *threads = NULL;
    struct worker_args *workers = NULL;
    struct timespec start;
    struct timespec end;
    uint64_t total_inside = 0;
    uint64_t base_samples;
    uint64_t remainder;
    uint64_t seed_base;
    uint64_t created_threads = 0;
    int status = EXIT_FAILURE;

    if (argc > 3) {
        usage(argv[0]);
        return EXIT_FAILURE;
    }

    if (argc >= 2 && parse_u64(argv[1], &total_samples) != 0) {
        fprintf(stderr, "Numero de amostras invalido: %s\n", argv[1]);
        usage(argv[0]);
        return EXIT_FAILURE;
    }

    if (argc >= 3 && parse_u64(argv[2], &thread_count) != 0) {
        fprintf(stderr, "Numero de threads invalido: %s\n", argv[2]);
        usage(argv[0]);
        return EXIT_FAILURE;
    }

    if (total_samples == 0 || thread_count == 0) {
        fprintf(stderr, "Amostras e threads precisam ser maiores que zero.\n");
        return EXIT_FAILURE;
    }

    if (thread_count > total_samples) {
        thread_count = total_samples;
    }

    threads = calloc((size_t)thread_count, sizeof(*threads));
    workers = calloc((size_t)thread_count, sizeof(*workers));
    if (threads == NULL || workers == NULL) {
        fprintf(stderr, "Falha ao alocar memoria.\n");
        goto cleanup;
    }

    base_samples = total_samples / thread_count;
    remainder = total_samples % thread_count;
    seed_base = (uint64_t)time(NULL) ^ UINT64_C(0xd1b54a32d192ed03);

    if (clock_gettime(CLOCK_MONOTONIC, &start) != 0) {
        fprintf(stderr, "clock_gettime falhou: %s\n", strerror(errno));
        goto cleanup;
    }

    for (uint64_t i = 0; i < thread_count; i++) {
        workers[i].samples = base_samples + (i < remainder ? 1 : 0);
        workers[i].seed = seed_base + i * UINT64_C(0x9e3779b97f4a7c15);
        workers[i].inside = 0;

        if (pthread_create(&threads[i], NULL, monte_carlo_worker,
                           &workers[i]) != 0) {
            fprintf(stderr, "pthread_create falhou na thread %" PRIu64 "\n", i);
            goto join_threads;
        }
        created_threads++;
    }

join_threads:
    for (uint64_t i = 0; i < created_threads; i++) {
        if (pthread_join(threads[i], NULL) != 0) {
            fprintf(stderr, "pthread_join falhou na thread %" PRIu64 "\n", i);
            goto cleanup;
        }
        total_inside += workers[i].inside;
    }

    if (created_threads != thread_count) {
        goto cleanup;
    }

    if (clock_gettime(CLOCK_MONOTONIC, &end) != 0) {
        fprintf(stderr, "clock_gettime falhou: %s\n", strerror(errno));
        goto cleanup;
    }

    printf("amostras: %" PRIu64 "\n", total_samples);
    printf("threads:  %" PRIu64 "\n", thread_count);
    printf("dentro:   %" PRIu64 "\n", total_inside);
    printf("pi:       %.12f\n",
           4.0 * (double)total_inside / (double)total_samples);
    printf("tempo:    %.6f s\n", elapsed_seconds(&start, &end));

    status = EXIT_SUCCESS;

cleanup:
    free(workers);
    free(threads);
    return status;
}
