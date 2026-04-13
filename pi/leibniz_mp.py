import math
import os
import time
import multiprocessing as mp


def leibniz_serial(n: int):
    p = 0.0  # acumulador da soma parcial

    for k in range(n):
        p += ((-1.0) ** k) / (2 * k + 1)

    # multiplica por 4 para obter a aproximacao de pi
    return 4.0 * p


def _leibniz_worker(args):
    start_k, end_k = args
    p = 0.0  # soma parcial local

    for k in range(start_k, end_k):
        p += ((-1.0) ** k) / (2 * k + 1)

    # retorna a soma parcial calculada pelo processo
    return p


def leibniz_parallel(n: int):
    # define o numero de processos com base no numero de nucleos da maquina
    processes = os.cpu_count() or 2

    # divide a quantidade total de termos entre os processos
    base = n // processes
    rest = n % processes

    tasks = []
    start_k = 0

    # monta os intervalos de termos para cada processo
    for i in range(processes):
        size = base + (1 if i < rest else 0)  # distribui o resto entre os primeiros processos
        end_k = start_k + size
        tasks.append((start_k, end_k))
        start_k = end_k

    # cria o pool de processos e executa as tarefas em paralelo
    with mp.Pool(processes=processes) as pool:
        p = pool.map(_leibniz_worker, tasks)

    # soma os resultados parciais e multiplica por 4
    return 4.0 * sum(p)


def benchmark(n: int = 5_000_000):
    start = time.perf_counter()
    pi_serial = leibniz_serial(n)
    t_serial = time.perf_counter() - start

    start = time.perf_counter()
    pi_parallel = leibniz_parallel(n)
    t_parallel = time.perf_counter() - start

    err_serial = abs(math.pi - pi_serial)
    err_parallel = abs(math.pi - pi_parallel)

    speedup = t_serial / t_parallel if t_parallel > 0 else float("inf")

    print("Leibniz")
    print(f"processos = {(os.cpu_count() or 2)}")
    print(f"serial \n pi = {pi_serial:.12f} \n tempo = {t_serial:.6f}s \n erro = {err_serial:.12f}")
    print(f"paralelo \n pi = {pi_parallel:.12f} \n tempo = {t_parallel:.6f}s \n erro = {err_parallel:.12f}")
    print(f"speedup = {speedup:.6f}")


# executa o benchmark
benchmark()
