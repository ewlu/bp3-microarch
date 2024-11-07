# bp3-microarch

This is some additional exploration on the microarchitecture of the banana
pi 3 similar to what Philip has
[here](https://github.com/preames/bp3-microarch).

The assembly testcases are generated from
[Microprobe](https://github.com/IBM/microprobe).

## Getting Started

### Host cross compiling

Current upstream microprobe is missing support for the banana pi and some
commonly used extensions. A pull request is currently in the works for the
support [here](https://github.com/IBM/microprobe/pull/44). For now, we'll apply
the patches manually.

```
git submodule update --init --recursive
cd microprobe
git am ../patches/*.patch
```

Once the patches have been applied, simply run `make` to get started compiling.
This will generate a directory `executables/` per target and a corresponding
tarball. Copy the tarball and the `run_perf.sh` file over to the banana pi.

### Banana Pi

Make sure `perf` is setup on the banana pi and `ssh` is enabled.

More detailed information on how to setup perf on the banana pi can be found
[here](https://github.com/preames/public-notes/blob/master/riscv/bp3-setup.rst#id5).

Move all of the executable tarballs into a directory called `to_execute` and run
`./run_perf.sh`. This will generate new tarballs with the results for data
analysis.

## Methodology

Microprobe has the option of generating benchmarks which run in an infinite
loop. Each loop consists of around 4k alternating instructions. For example, the
`ADDI_V0_ADDIW_V0` test loop looks like this:
```
ADDI    rd, rs, imm
ADDIW   rd, rs, imm
ADDI    rd, rs, imm
ADDIW   rd, rs, imm
...
```
and the `ADDI_V0_ADDI_V0` test loop looks like this:
```
ADDI    rd, rs, imm
ADDI    rd, rs, imm
ADDI    rd, rs, imm
ADDI    rd, rs, imm
...
```

We can take advantage of the infinite loop to use the `perf` tooling for all the
data collection.

The full script can be found in `run_perf.sh` but here's the general idea: If
we start the program in the background and sleep for a little bit, we can
ignore the program startup overhead and warm up the cache before jumping
directly into measuring instruction and cycle counts of the execution loop.
Even if perf starts in the middle of the execution loop, running the program
long enough would minimize the effect on the data.

To determine approximately how long to let perf run, I tested 1, 2, 5, 10, 20,
and 30 second intervals with a 2 second buffer after the initial program
execution. In the end, 10 seconds was chosen since it provided sufficient time
to amortize away potential uncontrollable costs while also not being too long
such that data collection takes forever.

