(import /janet-graphviz/build/graphviz :as graphviz)

(defn trim [s]
  (string/trim s "\""))

(defn make-attr [key val]
  @{:key (trim key) :val (trim val)})

(defn make-node [id attrs]
  @{:t "node" :id (trim id) :attrs attrs})

(defn make-edge [src dst attrs]
  @{:t "edge" :src (trim src) :dst (trim dst) :attrs attrs})

(def dot-grammar
  (peg/compile
    ~{:bare-id    (some (choice "_" "." :w))
      :quoted-if  (sequence "\"" (to "\"") "\"")
      :id         (choice :quoted-if :bare-id)
      :main       (sequence "digraph" :s+ (opt (sequence :id :s+)) "{"
                    (some (sequence :s+ :stmt)) :s+
                  "}" :s*)
      :stmt       (sequence (choice :edge-stmt :node-stmt) ";")
      :node-stmt  (replace
                    (sequence (capture :id :id) :attr-list)
                    ,make-node
                  )
      :edge-stmt  (replace
                    (sequence (capture :id :src) :s+ "->" :s+ (capture :id :dst) :attr-list)
                    ,make-edge
                  )
      :attr-list  (group
                    (sequence (any (sequence :s+ :attr)))
                    :attrs
                  )
      :attr       (replace
                    (sequence "[" (capture :id :attr-name) "=" (capture :id :attr-val) "]")
                    ,make-attr
                  )
    }))

(defn parse-dot [src]
  (peg/match dot-grammar src))

(defn make-graph [dot]
  (def id2idx @{})
  (def nodes @[])
  (def edges @[])

  (loop [n :in dot]
    (if (= (get n :t) "node")
      (do
        (def idx (length id2idx))
        (put id2idx (get n :id) idx)
        (array/push nodes n))))

  (loop [n :in dot]
    (if (= (get n :t) "edge")
      (do
        (def src (get n :src))
        (def dst (get n :dst))

        (if (nil? (get id2idx src))
          (do
            (put id2idx src (length nodes))
            (array/push nodes @{:id src :attrs @[]})))

        (if (nil? (get id2idx dst))
          (do
            (put id2idx dst (length nodes))
            (array/push nodes @{:id dst :attrs @[]}))))))

  (loop [n :in dot]
    (if (= (get n :t) "edge")
      (do
        (def src (get n :src))
        (def dst (get n :dst))
        (def u (get id2idx src))
        (def v (get id2idx dst))
        (array/push edges @{:u u :v v :attrs (get n :attrs)}))))

  @{:nodes nodes :edges edges})

(defn main [& args]
  (def src (slurp (get args 1)))
  (def dot (parse-dot src))
  # (pp dot)
  (def g (make-graph dot))

  # (loop [i :range [0 (length (get g :nodes))]]
  #   (do
  #     (print i)
  #     (pp (get (get g :nodes) i))))

  # (loop [i :range [0 (length (get g :edges))]]
  #   (do
  #     (pp (get (get g :edges) i))))

  (def layout (graphviz/layout (get g :nodes) (get g :edges)))
  (pp layout)
)
