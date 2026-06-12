# Makefile — pull the important Vivado reports into the repo after a run.
#
# Usage (from vivado/reports/):
#   make            # copy the latest impl + synth reports into this folder
#   make list       # show which source reports currently exist (no copy)
#
# Source = the multi-ray Vivado project on the Windows drive. Override on the
# command line if the project moves, e.g.  make PROJ=/mnt/c/.../project_other
# ---------------------------------------------------------------------------

FYP   := /mnt/c/Users/Ali/Documents/Imperial/FYP
PROJ  := $(FYP)/project_multiray
RUNS  := $(PROJ)/svo_raytracer.runs
IMPL  := $(RUNS)/impl_1
SYNTH := $(RUNS)/synth_1
WRAP  := svo_system_wrapper

.PHONY: all copy list clean

all: copy

# Copy a source report into the repo iff it exists; print what happened.
# $(1)=source path  $(2)=dest filename  $(3)=label
define grab
@if [ -f "$(1)" ]; then \
    cp -f "$(1)" "$(2)"; \
    printf "  [ok]   %-28s <- %s\n" "$(2)" "$$(basename '$(1)')"; \
else \
    printf "  [skip] %-28s (source missing)\n" "$(2)"; \
fi
endef

copy:
	@echo "Pulling reports from $(notdir $(PROJ)) ..."
	@echo "-- implementation --"
	@# Prefer post-route phys_opt timing summary; fall back to routed.
	@if [ -f "$(IMPL)/$(WRAP)_timing_summary_postroute_physopted.rpt" ]; then \
	    cp -f "$(IMPL)/$(WRAP)_timing_summary_postroute_physopted.rpt" timing_summary.txt; \
	    printf "  [ok]   %-28s <- %s\n" "timing_summary.txt" "timing_summary_postroute_physopted.rpt"; \
	elif [ -f "$(IMPL)/$(WRAP)_timing_summary_routed.rpt" ]; then \
	    cp -f "$(IMPL)/$(WRAP)_timing_summary_routed.rpt" timing_summary.txt; \
	    printf "  [ok]   %-28s <- %s\n" "timing_summary.txt" "timing_summary_routed.rpt"; \
	else \
	    printf "  [skip] %-28s (no timing summary yet)\n" "timing_summary.txt"; \
	fi
	$(call grab,$(IMPL)/$(WRAP)_utilization_placed.rpt,utilization_report.txt,util)
	$(call grab,$(IMPL)/$(WRAP)_clock_utilization_routed.rpt,clock_util.txt,clk util)
	$(call grab,$(IMPL)/$(WRAP)_drc_routed.rpt,drc_report.txt,drc)
	$(call grab,$(IMPL)/$(WRAP)_power_routed.rpt,power_report.txt,power)
	$(call grab,$(IMPL)/$(WRAP)_route_status.rpt,route_status.txt,route status)
	@# timing_after.txt is written by commands.tcl (report_timing_summary -file).
	$(call grab,$(FYP)/timing_after.txt,timing_after.txt,console timing)
	@echo "-- synthesis --"
	$(call grab,$(SYNTH)/$(WRAP)_utilization_synth.rpt,utilization_synth.txt,synth util)
	$(call grab,$(SYNTH)/runme.log,synth_log.txt,synth log)
	@echo "Done. 'git status' to see what changed."

list:
	@echo "Source reports in $(IMPL):"
	@ls -1 "$(IMPL)"/*.rpt 2>/dev/null | sed 's/^/  /' || echo "  (none — impl not finished?)"
	@echo "Source reports in $(SYNTH):"
	@ls -1 "$(SYNTH)"/*.rpt "$(SYNTH)"/runme.log 2>/dev/null | sed 's/^/  /' || echo "  (none)"

# Remove the copied reports (leaves this Makefile + any .xdc alone).
clean:
	@rm -f timing_summary.txt utilization_report.txt clock_util.txt drc_report.txt \
	       power_report.txt route_status.txt timing_after.txt utilization_synth.txt synth_log.txt
	@echo "Cleaned copied reports."
