import math
import os
import random
import time
import multiprocessing as mp


def montecarlo_serial(n: int):
    h = 0  # contador de acertos dentro do circulo
    rng = random.Random(12345)  # gerador com seed fixa para previsibilidade

    for _ in range(n):
        x = rng.random()  # coordenada x aleatoria
        y = rng.random()  # coordenada y aleatoria

        # verifica se o ponto esta dentro da circunferencia
        if x * x + y * y <= 1.0:
            h += 1

    # calcula o valor de pi
    return 4.0 * h / n


def _mc_worker(args):
    samples, seed = args
    rng = random.Random(seed)
    h = 0  # contador local de acertos

    # faz basicamente o mesmo que o serial
    for _ in range(samples):
        x = rng.random()
        y = rng.random()

        if x * x + y * y <= 1.0:
            h += 1

    return h


def montecarlo_parallel(n: int):
    # define o nemero de processos com base no numero de nucleos da maquina
    processes = os.cpu_count() or 2

    # divide a quantidade total de pontos entre os processos
    base = n // processes
    rest = n % processes

    tasks = []

    # monta a lista de tarefas para cada processo
    for i in range(processes):
        samples = base + (1 if i < rest else 0)  # distribui o resto entre os primeiros processos
        seed = 12345 + i  # usa sementes diferentes
        tasks.append((samples, seed))

    # cria o pool de processos e executa as tarefas em paralelo
    with mp.Pool(processes=processes) as pool:
        h = sum(pool.map(_mc_worker, tasks))

    # calcula o valor de pi
    return 4.0 * h / n


def benchmark(n: int = 5_000_000):
    start = time.perf_counter()
    pi_serial = montecarlo_serial(n)
    t_serial = time.perf_counter() - start

    start = time.perf_counter()
    pi_parallel = montecarlo_parallel(n)
    t_parallel = time.perf_counter() - start

    err_serial = abs(math.pi - pi_serial)
    err_parallel = abs(math.pi - pi_parallel)

    speedup = t_serial / t_parallel if t_parallel > 0 else float("inf")

    print("Monte Carlo")
    print(f"processos = {(os.cpu_count() or 2)}")
    print(f"serial \n pi = {pi_serial:.12f} \n tempo = {t_serial:.6f}s \n erro = {err_serial:.12f}")
    print(f"paralelo \n pi = {pi_parallel:.12f} \n tempo = {t_parallel:.6f}s \n erro = {err_parallel:.12f}")
    print(f"speedup = {speedup:.6f}")


# executa o benchmark
benchmark()
