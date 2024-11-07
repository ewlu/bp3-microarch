# Check if compiler is installed
ifeq (,$(shell which riscv64-unknown-elf-gcc))
	$(error "Error: riscv64-unknown-elf-gcc is not found in PATH")
endif


# Phony targets (not real files)
.PHONY: all init clean

# Default target
all: generated_asm/i-dep generated_asm/f-dep generated_asm/i generated_asm/f generated_asm/i-i2f generated_asm/i-f2i generated_asm/f-i2f generated_asm/f-f2i generated_asm/ifconvert-dep generated_asm/ifconvert-direct-dep

help: ## Print help commands
	@egrep -h '\s##\s' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":[^:]*?## "}; {printf "\033[36m  %-30s\033[0m %s\n", $$1, $$2}'

init: stamps/init ## Initialize submodules and environments

stamps/init:
	git submodule update --init --recursive
	mkdir -p stamps
	cd microprobe && ./bootstrap_environment.sh
	touch stamps/init

clean: ## Clean object files and executables
	rm -rf generated_asm executables

# Float/Int insns excluding conversions
F ?= FADD.D_V0,FNMADD.D_V0,FNMSUB.D_V0,FSQRT.D_V0,FMSUB.D_V0,FDIV.D_V0,FMUL.D_V0,FSGNJX.D_V0,FMIN.D_V0,FMADD.D_V0,FSUB.D_V0,FSGNJN.D_V0,FSGNJ.D_V0,FMAX.D_V0,FCVT.D.S_V0,FCVT.S.D_V0
I-FULL ?= ADDIW_V0,REMU_V0,MULHSU_V0,SLLW_V0,SLTU_V0,SRAIW_V0,ADD_V0,SRLIW_V0,SRLI_V0,LUI_V0,SLLIW_V0,MULH_V0,MULHU_V0,SRAI_V0,OR_V0,SLT_V0,SRLW_V0,SUBW_V0,SLTIU_V0,SRA_V0,SUB_V0,XOR_V0,DIVU_V0,ADDW_V0,DIV_V0,AND_V0,REM_V0,DIVUW_V0,XORI_V0,ORI_V0,SLTI_V0,SRAW_V0,SLLI_V0,SRL_V0,ADDI_V0,MUL_V0,MULW_V0,AUIPC_V0,ANDI_V0,SLL_V0,REMUW_V0
I-REDUCED ?= ADD_V0,LUI_V0,SRAI_V0,OR_V0,SLT_V0,SRA_V0,SUB_V0,XOR_V0,DIV_V0,AND_V0,REM_V0,XORI_V0,ORI_V0,SLTI_V0,SLLI_V0,SRL_V0,ADDI_V0,MUL_V0,AUIPC_V0,ANDI_V0,SLL_V0,SRLI_V0

# Float/Int conversion insns
F2I ?= FCVT.WU.D_V0,FCVT.W.D_V0,FCVT.L.D_V0,FLE.D_V0,FLT.D_V0,FCLASS.D_V0,FCVT.LU.D_V0,FMV.X.D_V0,FEQ.D_V0
I2F ?= FMV.D.X_V0,FCVT.D.LU_V0,FCVT.D.L_V0,FCVT.D.W_V0,FCVT.D.WU_V0

generated_asm/i-dep: ## Generate basic integer microbenchmarks with instruction dependencies. (Second insn depends on first's output)
	mkdir -p generated_asm/i-dep
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-dd 1 \
		-combinations \
		-D ../generated_asm/i-dep \
		-is 2 -ig $(I-FULL))
	./compile.sh i-dep


generated_asm/f-dep: ## Generate basic float microbenchmarks with instruction dependencies. (Second insn depends on first's output)
	mkdir -p generated_asm/f-dep
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-dd 1 \
		-combinations \
		-D ../generated_asm/f-dep \
		-is 2 -ig $(F))
	./compile.sh f-dep

generated_asm/i: ## Generate basic integer microbenchmarks with no instruction dependencies.
	mkdir -p generated_asm/i
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-dd 0 \
		-combinations \
		-D ../generated_asm/i \
		-is 2 -ig $(I-FULL))
	./compile.sh i

generated_asm/f: ## Generate basic float microbenchmarks with no instruction dependencies.
	mkdir -p generated_asm/f
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-dd 0 \
		-combinations \
		-D ../generated_asm/f \
		-is 2 -ig $(F))
	./compile.sh f

generated_asm/i-i2f: ## Generate basic int, int/float conversion microbenchmarks with no instruction dependencies.
	mkdir -p generated_asm/i-i2f
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-D ../generated_asm/i-i2f \
		-combinations \
		-is 2 \
		-ig $(I-REDUCED) \
		$(I2F) \
		-im 1 2)
	./compile.sh i-i2f


generated_asm/i-f2i: ## Generate basic int, int/float conversion microbenchmarks with no instruction dependencies.
	mkdir -p generated_asm/i-f2i
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-D ../generated_asm/i-f2i \
		-combinations \
		-is 2 \
		-ig $(I-REDUCED) \
		$(F2I) \
		-im 1 2)
	./compile.sh i-f2i


generated_asm/f-i2f: ## Generate basic float, int/float conversion microbenchmarks with no instruction dependencies.
	mkdir -p generated_asm/f-i2f
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-D ../generated_asm/f-i2f \
		-combinations \
		-is 2 \
		-ig $(F) \
		$(I2F) \
		-im 1 2)
	./compile.sh f-i2f


generated_asm/f-f2i: ## Generate basic float, int/float conversion microbenchmarks with no instruction dependencies.
	mkdir -p generated_asm/f-f2i
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-D ../generated_asm/f-f2i \
		-combinations \
		-is 2 \
		-ig $(F) \
		$(F2I) \
		-im 1 2)
	./compile.sh f-f2i


generated_asm/ifconvert-dep: ## Generate basic int/float conversion microbenchmarks with instruction dependencies. (Each insn depends on previous' output)
	mkdir -p generated_asm/ifconvert-dep
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-D ../generated_asm/ifconvert-dep \
		-dd 1 \
		-combinations \
		-is 4 \
		-ig $(F2I) \
		ADD_V0 \
		$(I2F) \
		FADD.D_V0 \
		-im 1 2 3 4)
	./compile.sh ifconvert-dep

generated_asm/ifconvert-direct-dep: ## Generate direct int/float conversion microbenchmarks with instruction dependencies. (Each insn depends on previous' output)
	mkdir -p generated_asm/ifconvert-direct-dep
	cd microprobe && . ./activate_microprobe && \
	(python3 ./targets/generic/tools/mp_seq.py -p -s \
		-T riscv_v22-riscv_generic-riscv64_bp3 \
		-D ../generated_asm/ifconvert-dep \
		-dd 1 \
		-combinations \
		-is 2 \
		-ig $(F2I) \
		$(I2F) \
		-im 1 2)
	./compile.sh ifconvert-direct-dep
