# Registry benchmarks

Run the matrix and generate a README preview from MSYS2, Git Bash, or WSL:

~~~bash
node dependencies/packages/checks/testSuites/run.cjs registry --benchmark
~~~

The benchmark writes charts, raw samples, and measurement metadata under build/artifacts/benchmarks. Studio runs paired trials with identical workloads. The benchmark alternates method order and excludes fixture setup, registration, warmup, and checksum validation from the timed loops.
