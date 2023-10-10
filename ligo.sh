
# shortcut ligo commands
# useage: `source ligo.sh` and then call defined commands directly from CLI

ligo() {
  docker run --rm -v $PWD:$PWD -w $PWD ligolang/ligo:1.0.0 $@
}

compile() {
  echo "compiling $1 -> $3"
  ligo compile contract $1 -m $2 -o $3
}

compile-expression() {
  echo "compiling $2"
  ligo compile expression --init-file $1 cameligo $2
}
