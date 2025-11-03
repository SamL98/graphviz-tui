(import /build/graphviz :as graphviz)
(def nodes @[@{:id "A" :attrs @[]} @{:id "B" :attrs @[]}])
(def edges @[@{:u 0 :v 1 :attrs @[]}])
(pp (graphviz/layout nodes edges))
