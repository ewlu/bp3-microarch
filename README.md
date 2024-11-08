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

## Basic Exploration

A full breakdown of the cross product of the integer and float operations can be
visualized in [these tables](https://ewlu.github.io/bp3-microarch/)

### Integer Operation Throughput and Latency

|    | insn      |   throughput IPC |   latency IPC |
|---:|:----------|-----------------:|--------------:|
|  0 | DIVUW_V0  |         0.333544 |      1.03675  |
|  1 | AND_V0    |         1.99095  |      0.333993 |
|  2 | AUIPC_V0  |         0.666822 |      0.333568 |
|  3 | SLLIW_V0  |         1.99731  |      0.665411 |
|  4 | REMU_V0   |         0.333553 |      1.07566  |
|  5 | MUL_V0    |         0.333541 |      1.07337  |
|  6 | OR_V0     |         1.997    |      1.07321  |
|  7 | MULW_V0   |         0.999818 |      1.0347   |
|  8 | SLL_V0    |         1.99089  |      1.03678  |
|  9 | SLLI_V0   |         1.99711  |      1.03676  |
| 10 | ADDIW_V0  |         1.99724  |      0.33622  |
| 11 | ANDI_V0   |         1.99713  |      1.0367   |
| 12 | ADD_V0    |         1.99304  |      1.07652  |
| 13 | ADDI_V0   |         1.99706  |      0.333549 |
| 14 | DIVU_V0   |         0.333542 |      1.03671  |
| 15 | SLTI_V0   |         1.99723  |      1.07451  |
| 16 | LUI_V0    |         1.99589  |      1.03676  |
| 17 | MULHSU_V0 |         0.250689 |      1.07648  |
| 18 | SLTU_V0   |         1.99715  |      0.174471 |
| 19 | SLT_V0    |         1.9952   |      0.171048 |
| 20 | SRAIW_V0  |         1.9971   |      0.175118 |
| 21 | MULHU_V0  |         0.252544 |      0.350679 |
| 22 | SRAI_V0   |         1.99718  |      0.206179 |
| 23 | SRAW_V0   |         1.99113  |      1.03667  |
| 24 | SRA_V0    |         1.99726  |      0.33353  |
| 25 | SRLI_V0   |         1.99715  |      1.07654  |
| 26 | SRLW_V0   |         1.99718  |      1.03672  |
| 27 | MULH_V0   |         0.250265 |      1.07648  |
| 28 | SRL_V0    |         1.99706  |      1.03675  |
| 29 | SUBW_V0   |         1.99714  |      1.03456  |
| 30 | SUB_V0    |         1.99726  |      1.07551  |
| 31 | XORI_V0   |         1.99532  |      1.0765   |
| 32 | XOR_V0    |         1.99713  |      1.07656  |
| 33 | ADDW_V0   |         1.99549  |      1.07655  |
| 34 | REMUW_V0  |         0.333553 |      1.07591  |
| 35 | REM_V0    |         0.333544 |      1.03678  |
| 36 | DIV_V0    |         0.333545 |      1.07649  |
| 37 | ORI_V0    |         1.99087  |      1.99725  |
| 38 | SLLW_V0   |         1.9972   |      1.07653  |
| 39 | SLTIU_V0  |         1.99721  |      0.33563  |
| 40 | SRLIW_V0  |         1.99723  |      1.99687  |

The Instructions Per Cycle (IPC) numbers show that in general, two operations
with no dependencies can be completed in a single cycle. Operations with
dependencies mostly finish within a single cycle. This makes sense due to the
Spacemit core having a dual-issue, in-order pipeline.

### Float Operation Throughput and Latency

|    | insn        |   throughput IPC |   latency IPC |
|---:|:------------|-----------------:|--------------:|
|  0 | FMAX.D_V0   |         1.99611  |      0.250373 |
|  1 | FMIN.D_V0   |         1.9963   |      0.333673 |
|  2 | FMSUB.D_V0  |         0.99929  |      0.333592 |
|  3 | FCVT.D.S_V0 |         0.998121 |      0.200317 |
|  4 | FCVT.S.D_V0 |         0.995978 |      0.333596 |
|  5 | FDIV.D_V0   |         0.111434 |      0.251143 |
|  6 | FADD.D_V0   |         1.77465  |      0.333673 |
|  7 | FMADD.D_V0  |         0.995482 |      0.333684 |
|  8 | FSGNJ.D_V0  |         0.997353 |      0.333574 |
|  9 | FSGNJN.D_V0 |         0.998893 |      0.333588 |
| 10 | FSUB.D_V0   |         1.98645  |      0.11143  |
| 11 | FMUL.D_V0   |         1.99363  |      0.200321 |
| 12 | FNMADD.D_V0 |         0.999248 |      0.20031  |
| 13 | FSGNJX.D_V0 |         0.999777 |      0.200306 |
| 14 | FNMSUB.D_V0 |         0.999312 |      0.336929 |
| 15 | FSQRT.D_V0  |         0.111431 |      0.116053 |

Contrary to the integer operations, it appears most of the float operations with
no dependencies finish in around 1 cycle and operations with dependencies take
more than 1 cycle to complete
