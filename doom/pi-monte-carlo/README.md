# Pi por Monte Carlo com pthreads

Projeto simples em C para estimar pi usando Monte Carlo no Linux BSP da DE10S.
Por padrao ele usa 2 threads, uma para cada core ARM do HPS.

## Compilar no alvo

```sh
cd pi-monte-carlo
make
```

O `Makefile` usa `gcc` por padrao e inclui automaticamente
`build/sysroot/usr/include` se esse diretorio existir no momento do build.
Tambem adiciona `build/sysroot/usr/lib` ao link se existir.

Para apontar outro sysroot:

```sh
make SYSROOT=/caminho/para/build/sysroot
```

## Executar

```sh
./pi_monte_carlo
./pi_monte_carlo 10000000 2
```

Argumentos:

1. quantidade total de amostras
2. quantidade de threads

Tambem existe um alvo de conveniencia:

```sh
make run SAMPLES=10000000 THREADS=2
```
