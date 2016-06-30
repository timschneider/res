#! /usr/bin/octave
# Das ist die Berechnung der Größen im Cache

sdram_address_space_mebibyte	= 16
sdram_address_space_byte		= sdram_address_space_mebibyte * 1024 * 1024
address_length_bits				= log2(sdram_address_space_byte)
cache_size_bytes 				= 4096																								# Gesammtgröße des Caches
cache_line_length_words			= 8																									# Länge einer Cacheline in 32-bit Worten
cache_line_length_bytes			= cache_line_length_words*4																			# Länge einer Cacheline in bytes
cache_line_word_index_bits		= log2(cache_line_length_words)																		# Anzahl Bits, die benötigt werden, um in einer Cacheline das richtige Wort herauszufischen
byte_select_index_bits			= 2																									# Anzahl Bits, die benötigt werden, um in einem Wort das richtige Byte herauszufischen
cache_number_lines				= cache_size_bytes/cache_line_length_bytes															# Anzahl der Cache-Lines
cache_index_bits				= log2(cache_number_lines)																			# Anzahl Bits, die benötigt werden, um im Cache die richtige Line zu addressieren
cache_tag_bits					= address_length_bits - cache_index_bits - cache_line_word_index_bits - byte_select_index_bits		# Anzahl Bits, die den Tag bilden
cache_flag_bits					= 1																									# Anzahl Bits, die für Flaggen reserviert sind. Flaggen: Invalid (Cacheline ist noch nicht gefüllt), ...
cache_tag_and_flag_bits			= cache_tag_bits + cache_flag_bits
cache_no_BRAMS					= 1 +ceil(cache_number_lines*cache_line_length_words/512)											# Die BRAMS unterstützen unter anderem die Konfiguration 512x32bit, also gerade 512 mal ein Wort
																																	# Die 1+ ist für Tags + Flags



cache_line_length_total_bytes	= (cache_tag_and_flag_bits)/8 + cache_line_length_bytes												# Anzahl Bytes, die für eine Cacheline benötigt werden
cache_line_length_total_bits	= cache_line_length_total_bytes*8																	# Anzahl Bits, die für eine Cacheline benötigt würden.

