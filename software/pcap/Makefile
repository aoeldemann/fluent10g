.PHONY: all clean

all:
	gcc -o pcap_import pcap_import.c -lpcap -lm
	gcc -o pcap_export pcap_export.c -lpcap

clean:
	rm -rf pcap_import pcap_export
