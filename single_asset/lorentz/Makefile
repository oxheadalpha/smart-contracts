
get_stack:
	which stack || curl -sSL https://get.haskellstack.org/ | sh

get_morley_ledgers:
	ls morley-ledgers || git clone https://gitlab.com/morley-framework/morley-ledgers.git
	cd morley-ledgers && git checkout e9ef09eefd476b07635d7052cf6f1916cd04063d

build_morley_ledgers: get_stack get_morley_ledgers
	cd morley-ledgers && stack build

fa12: build_morley_ledgers
	ls out || mkdir out
	rm -f out/fa12_lorentz.tz
	cd morley-ledgers && stack exec morley-ledgers -- print --name ManagedLedger --output ../out/fa12_lorentz.tz

run: build_morley_ledgers
	cd morley-ledgers && stack exec morley-ledgers -- $(ARG)

test: build_morley_ledgers
	cd morley-ledgers && stack test

