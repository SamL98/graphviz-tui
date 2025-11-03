(declare-project :name "graphviz")

(def cflags
  [
   "-I/usr/local/Cellar/graphviz/7.0.5/include"
   ])

(def lflags
  [
   "-L/usr/local/Cellar/graphviz/7.0.5/lib"
   "-lcgraph"
   "-lgvc"
  ])

(declare-native
  :name "graphviz"
  :cflags  [;default-cflags ;cflags]
  :ldflags [;default-lflags ;lflags]
  :source @["graphviz.c"])
