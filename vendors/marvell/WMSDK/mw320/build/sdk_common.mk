# Copyright (C) 2008-2019, Marvell International Ltd.
# All Rights Reserved.
#
# Description:
# ------------
# This file, sdk_common.mk contains following things:
#
# 	toolchain variables
# 	command variables used by build system

# .config should already have been included before this

# Step 0: Default target is all
all:

# Variables handled by specific toolchain file.
tc-cortex-m3-$(CONFIG_CPU_MC200) := y
tc-cortex-m4-$(CONFIG_CPU_MW300) := y
tc-lto-$(CONFIG_ENABLE_LTO) := y

######## Default variables
board_name-$(CONFIG_CPU_MC200) := mc200_8801
board_name-$(CONFIG_CPU_MW300) := mw300_rd
BOARD ?= $(board_name-y)

arch_name-$(CONFIG_CPU_MC200) := mc200
arch_name-$(CONFIG_CPU_MW300) := mw300

####### Misc Handling ###########
# Following apps will be built only until axf
b-axf-only :=

# Step 1: Initialize the toolchain
include build/toolchains/toolchain.mk

# Step 2: Setup our own variables

global-cflags-y += \
	 -Isdk/src/incl/sdk                             \
	 -Isdk/src/incl/sdk/crypto                      \
	 -Isdk/src/incl/sdk/drivers                     \
	 -Isdk/src/incl/sdk/drivers/$(arch_name-y)      \
	 -Isdk/src/incl/sdk/drivers/$(arch_name-y)/regs \
	 -Isdk/src/incl/sdk/drivers/wlan                \
	 -Isdk/src/incl/sdk/drivers/bt                	\
	 -Isdk/src/incl/libc/$(tc-env)

######### Tools
# Step 3: Handle development host specific options
# devhost is towards the end, so it can override stuff defined from above
include build/host/devhost.mk

t_which ?= which
t_cp    ?= $(shell $(t_which) cp | tail -1)
t_mv    ?= $(shell $(t_which) mv | tail -1)
t_cmp   ?= $(shell $(t_which) cmp | tail -1)
t_mkdir ?= $(shell $(t_which) mkdir | tail -1)
t_cat   ?= $(shell $(t_which) cat | tail -1)
t_rm    ?= $(shell $(t_which) rm | tail -1)
t_printf ?= $(shell $(t_which) printf | tail -1)
t_python ?= $(shell $(t_which) python | tail -1)

cmd_mkdir ?= $(t_mkdir) -p $(1)

##################################
t_kconf  ?= sdk/tools/bin/$(os_dir)/conf$(file_ext)
t_mconf  ?= sdk/tools/bin/$(os_dir)/mconf$(file_ext)
t_mkftfs ?= sdk/tools/bin/flash_pack.py

######## Secure Boot Handling ####
sec_archs:= mw300
b-secboot-y := $(and $(filter-out 0,$(SECURE_BOOT)),$(filter $(arch_name-y),$(sec_archs)))

ifeq ($(b-secboot-y),)
  b-secboot-y := n
  ifeq ($(CONFIG_SECURE_PSM_SUPPORT),y)
    CONFIG_SECURE_PSM := y
    ifeq ($(CONFIG_SECURE_MFG_BIN),y)
        SECURE_PSM_KEY := $(subst 0x,,$(CONFIG_SECURE_PSM_KEY))
        SECURE_PSM_KEY := $(subst 0X,,$(SECURE_PSM_KEY))
        SECURE_PSM_NONCE := $(subst 0x,,$(CONFIG_SECURE_PSM_NONCE))
        SECURE_PSM_NONCE := $(subst 0X,,$(SECURE_PSM_NONCE))
    endif
  endif
else
  b-secboot-y := y
  CONFIG_SECURE_PSM := y
  # SECURE_PSM_KEY and SECURE_PSM_NONCE will be populated from security configuration file
endif

ifeq ($(b-secboot-y),y)
  ifeq ($(NOISY),1)
     secboot_flags := -v
  endif
  SECURE_CONF_DIR ?= sboot_conf

  t_secconf := sdk/tools/bin/secconf.py
  t_secboot := sdk/tools/bin/secureboot.py
  ks_hdr := sdk/src/incl/sdk/keystore.h
  sec_conf_dir := $(call b-abspath,$(SECURE_CONF_DIR))
  sec_conf := $(shell $(t_python) $(t_secconf) -d $(sec_conf_dir) -f $(SECURE_BOOT))

  $(if $(sec_conf),,$(error Secure boot build failed))

  # include makefile helper generated by $(t_secureboot)
  sec_type_mk := $(sec_conf_dir)/sboot-type.mk
  -include $(sec_type_mk)
  -include $(sec_type_mk).cmd

  # include the otp_prog app, if not already included using APP variable
  ifeq ($(findstring otp_prog,$(APP)),)
    subdir-y += $(b-examples-path-y)/mfg/otp_prog
  endif
endif


