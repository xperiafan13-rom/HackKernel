/*
 * ld script to make ARM Linux kernel
 * taken from the i386 version by Russell King
 * Written by Martin Mares <mj@atrey.karlin.mff.cuni.cz>
 */

#include <asm-generic/vmlinux.lds.h>
#include <asm/thread_info.h>
#include <asm/memory.h>
#include <asm/page.h>
#include <asm/pgtable.h>

#define ARM_EXIT_KEEP(x)
#define ARM_EXIT_DISCARD(x)	x

OUTPUT_ARCH(aarch64)
ENTRY(_text)

jiffies = jiffies_64;

#define HYPERVISOR_TEXT					\
	/*						\
	 * Force the alignment to be compatible with	\
	 * the vectors requirements			\
	 */						\
	. = ALIGN(2048);				\
	VMLINUX_SYMBOL(__hyp_idmap_text_start) = .;	\
	*(.hyp.idmap.text)				\
	VMLINUX_SYMBOL(__hyp_idmap_text_end) = .;	\
	VMLINUX_SYMBOL(__hyp_text_start) = .;		\
	*(.hyp.text)					\
	VMLINUX_SYMBOL(__hyp_text_end) = .;

#ifdef CONFIG_DEBUG_ALIGN_RODATA
#define ALIGN_DEBUG_RO			. = ALIGN(1<<SECTION_SHIFT);
#define ALIGN_DEBUG_RO_MIN(min)		ALIGN_DEBUG_RO
#else
#define ALIGN_DEBUG_RO
#define ALIGN_DEBUG_RO_MIN(min)		. = ALIGN(min);
#endif

SECTIONS
{
	/*
	 * XXX: The linker does not define how output sections are
	 * matching the same input section name.  There is no documented
	 * order of matching.
	 */
	/DISCARD/ : {
		ARM_EXIT_DISCARD(EXIT_TEXT)
		ARM_EXIT_DISCARD(EXIT_DATA)
		EXIT_CALL
		*(.discard)
		*(.discard.*)
	}

	. = PAGE_OFFSET + TEXT_OFFSET;

	.head.text : {
		_text = .;
		HEAD_TEXT
	}
	.text : {			/* Real text segment		*/
		_stext = .;		/* Text and read-only data	*/
			__exception_text_start = .;
			*(.exception.text)
			__exception_text_end = .;
			IRQENTRY_TEXT
			TEXT_TEXT
			SCHED_TEXT
			LOCK_TEXT
			HYPERVISOR_TEXT
			*(.fixup)
			*(.gnu.warning)
		. = ALIGN(16);
		*(.got)			/* Global offset table		*/
	}

	ALIGN_DEBUG_RO
	RO_DATA(PAGE_SIZE)
	EXCEPTION_TABLE(8)
	NOTES
	ALIGN_DEBUG_RO
	_etext = .;			/* End of text and rodata section */

	ALIGN_DEBUG_RO_MIN(PAGE_SIZE)
	__init_begin = .;

	INIT_TEXT_SECTION(8)
	.exit.text : {
		ARM_EXIT_KEEP(EXIT_TEXT)
	}

	ALIGN_DEBUG_RO_MIN(16)
	.init.data : {
		INIT_DATA
		INIT_SETUP(16)
		INIT_CALLS
		CON_INITCALL
		SECURITY_INITCALL
		INIT_RAM_FS
	}
	.exit.data : {
		ARM_EXIT_KEEP(EXIT_DATA)
	}

	PERCPU_SECTION(64)

	__init_end = .;

	. = ALIGN(32);
	__start_hwlog_tag = .;
	__start_hwlog_tag : {
        *(__hwlog_tag)
	}
	__stop_hwlog_tag = .;

	. = ALIGN(PAGE_SIZE);
	_data = .;
	_sdata = .;
	RW_DATA_SECTION(64, PAGE_SIZE, THREAD_SIZE)
	_edata = .;

	BSS_SECTION(0, 0, 0)

	. = ALIGN(PAGE_SIZE);
	idmap_pg_dir = .;
	. += IDMAP_DIR_SIZE;
	swapper_pg_dir = .;
	. += SWAPPER_DIR_SIZE;

	_end = .;
	STABS_DEBUG
	.comment 0 : { *(.comment) }
}

/*
 * The HYP init code can't be more than a page long.
 */
ASSERT(((__hyp_idmap_text_start + PAGE_SIZE) > __hyp_idmap_text_end),
       "HYP init code too big")
