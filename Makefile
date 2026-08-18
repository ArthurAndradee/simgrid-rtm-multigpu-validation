CC       = mpicc
NVCC     = nvcc
BACKEND ?= openmp
PROFILE ?= none
ARCH    ?= sm_80

SRCDIR   = src
INCDIR   = include
BUILDDIR = bin
OBJDIR   = $(BUILDDIR)/obj

CFLAGS   = -I$(INCDIR) -Wall -O3 -g
LDFLAGS  = -lm

CUDA_CFLAGS    = -I$(INCDIR) -g -gencode arch=compute_$(subst sm_,,$(ARCH)),code=$(ARCH) -allow-unsupported-compiler
CUDA_LINK_LIBS = -L$(CUDA_PATH)/lib -L$(CUDA_PATH)/lib64 -lcudart

SOURCES_C_COMMON = $(filter-out $(wildcard $(SRCDIR)/*_propagate.c) $(SRCDIR)/device_data.c $(SRCDIR)/derivatives.c $(SRCDIR)/sample.c, $(wildcard $(SRCDIR)/*.c))

# Profile configuration
ifeq ($(PROFILE), mpip)
    LDFLAGS += -lmpiP
else ifeq ($(PROFILE), akypuera)
    LDFLAGS += -laky
endif

ifeq ($(BACKEND), openmp)
    SOURCES_C    := $(SOURCES_C_COMMON) $(SRCDIR)/openmp_propagate.c $(SRCDIR)/device_data.c
    SOURCES_CUDA :=
    CFLAGS       += -fopenmp
    LDFLAGS      += -fopenmp

else ifeq ($(BACKEND), simgrid)
    CC           := smpicc
    CFLAGS       += -DSIMGRID -fopenmp
    LDFLAGS      += -fopenmp
    SOURCES_C    := $(SOURCES_C_COMMON) $(SRCDIR)/openmp_propagate.c $(SRCDIR)/device_data.c
    SOURCES_CUDA :=

else ifeq ($(BACKEND), cuda)
    SOURCES_C    := $(SOURCES_C_COMMON)
    SOURCES_CUDA := $(SRCDIR)/cuda_propagate.cu $(SRCDIR)/device_data.cu
    LDFLAGS      += $(CUDA_LINK_LIBS)

else ifeq ($(BACKEND), simgrid_cuda)
    CC           := smpicc
    SOURCES_C    := $(SOURCES_C_COMMON)
    SOURCES_CUDA := $(SRCDIR)/cuda_propagate.cu $(SRCDIR)/device_data.cu
    
    CFLAGS       += -DSIMGRID
    CUDA_CFLAGS  += -Xcompiler -fPIC
    CUDA_CFLAGS  += -ccbin g++
    CUDA_CFLAGS  += -DSIMGRID
    # -lcudart (dynamic), NOT -lcudart_static -- kept from an earlier fix
    # attempt (job 2186228, 2026-08-12) that turned out NOT to be the actual
    # root cause (see below), but is harmless/correct to keep since
    # BACKEND=cuda already links dynamically too.
    LDFLAGS      += -L$(CUDA_PATH)/lib -L$(CUDA_PATH)/lib64 -lcudart -lstdc++ -lpthread -ldl -lrt
    # UNRESOLVED as of 2026-08-12 (jobs 2185769/2186228), ran out of
    # allocation time before landing a fix -- next session, start here:
    #
    # Symptom: "dlopen failed for bin/dc: cannot dynamically load
    # position-independent executable (errno: 0)" on every simgrid_cuda run,
    # regardless of smpi/privatization:no.
    #
    # IMPORTANT, checked live (`smpicc -show` / read
    # .../simgrid-4.1/bin/smpicc source directly, chuc-2, job 2185769):
    # smpicc's OWN wrapper unconditionally appends `-fPIC` to every
    # invocation (compile AND link), and appends `-shared -lsimgrid -lm
    # -Wl,-z,defs` to every LINK invocation (i.e. any call without `-c`) --
    # this happens regardless of anything in this Makefile's CFLAGS/LDFLAGS,
    # placed *after* our own flags on the underlying gcc command line. This
    # means bin/dc was ALREADY being linked as a proper `-shared -fPIC`
    # object (real ET_DYN shared library, not a PIE main executable) even
    # before any of the fixes below -- so the PIE-vs-shared-library
    # hypothesis that motivated attempt #2 was WRONG, or at least
    # incomplete. The real root cause of the dlopen failure is still
    # unknown.
    #
    # Tried live and did NOT work:
    #   1. -lcudart instead of -lcudart_static (this LDFLAGS line) -- same
    #      error, unchanged.
    #   2. Adding -fno-pie to CFLAGS/CUDA_CFLAGS (-Xcompiler -fno-pie) plus
    #      -no-pie to LDFLAGS -- redundant/moot per the smpicc finding
    #      above, AND broke the BUILD itself: `ld.bfd: cuda_propagate.o:
    #      relocation R_X86_64_32 against symbol ... can not be used when
    #      making a shared object; recompile with -fPIC` (nvcc's
    #      -Xcompiler -fno-pie apparently made cuda_propagate.o emit
    #      non-PIC relocations, incompatible with smpicc's forced -shared
    #      link). Reverted -- this Makefile is back to the state that at
    #      least builds and runs (but still hits the dlopen error).
    #
    # CONFIRMED, dead end (job 2185769, chuc-2, 2026-08-12): ran
    # `readelf -h bin/dc` / `readelf -d bin/dc` on the actual built binary --
    # `Type: DYN (Shared object file)`, FLAGS_1 only has `NOW` (BIND_NOW),
    # no PIE flag present. The PIE hypothesis is fully disproven: bin/dc is
    # already a completely normal, correctly-formed ET_DYN shared object
    # with no PIE marker, exactly what dlopen() is supposed to accept. Yet
    # dlopen() on this exact file still fails with "cannot dynamically load
    # position-independent executable" at runtime. The root cause is NOT in
    # how this Makefile links the binary -- do not re-attempt PIE/PIC-flag
    # changes here without new evidence.
    #
    # Next things to try (not yet attempted):
    #   a. The CUDA runtime itself is now the prime suspect: its
    #      __attribute__((constructor)) fatbinary-registration hooks, TLS
    #      usage, or global/static state may be incompatible with being
    #      dlopen()ed as a non-main shared object (as opposed to a normal
    #      -shared .so with no such runtime hooks) -- even though the ELF
    #      headers look fine, something CUDA does at dlopen-time may trip
    #      glibc's specific PIE-rejection code path (which can apparently
    #      trigger for reasons beyond just the DF_1_PIE flag -- worth
    #      reading glibc's elf/dl-load.c source for this exact message to
    #      find ALL the conditions that produce it, not just the DF_1_PIE
    #      one assumed here).
    #   b. Try a minimal repro: a trivial smpicc-built CUDA program (empty
    #      kernel) under the same --cfg=smpi/privatization flags, to check
    #      whether ANY CUDA+SMPI+dlopen combination works at all here, or
    #      whether it's specific to this codebase.
    #   c. Check SimGrid's own docs/examples/mailing list for CUDA +
    #      privatization -- this may be a known SimGrid/CUDA incompatibility
    #      with a documented workaround (e.g. privatization via mmap/fork
    #      instead of dlopen, if SimGrid supports that mode).

else
    $(error Unsupported backend: $(BACKEND). Supported: openmp, simgrid, cuda, simgrid_cuda)
endif

OBJECTS_C    = $(patsubst $(SRCDIR)/%.c,$(OBJDIR)/%.o,$(SOURCES_C))
OBJECTS_CUDA = $(patsubst $(SRCDIR)/%.cu,$(OBJDIR)/%.o,$(SOURCES_CUDA))

TARGET = $(BUILDDIR)/dc

all: $(TARGET)

$(TARGET): $(OBJECTS_C) $(OBJECTS_CUDA)
	@mkdir -p $(@D)
	$(CC) -o $@ $^ $(LDFLAGS)

$(OBJECTS_C): $(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) -c $< -o $@ $(CFLAGS)

$(OBJECTS_CUDA): $(OBJDIR)/%.o: $(SRCDIR)/%.cu
	@mkdir -p $(@D)
	$(NVCC) -c $< -o $@ $(CUDA_CFLAGS)

clean:
	rm -rf $(BUILDDIR)

.PHONY: all clean
