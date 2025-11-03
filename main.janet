(import /janet-graphviz/build/graphviz :as graphviz)

(defn trim [s]
  (string/trim s "\""))

(defn make-attr [key val]
  @{(trim key) (trim val)})

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

(defn convert-attrs [as]
  (def attrs @{})

  (loop [a :in as]
    (loop [[k v] :in (pairs a)]
      (put attrs k v)))

  attrs)

(defn make-graph [dot]
  (def id2idx @{})
  (def nodes @[])
  (def edges @[])

  (loop [n :in dot]
    (if (= (get n :t) "node")
      (do
        (def idx (length id2idx))
        (def id (get n :id))
        (put id2idx id idx)

        (def attrs (convert-attrs (get n :attrs)))
        (array/push nodes @{:id id :attrs attrs}))))

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
        (def attrs (convert-attrs (get n :attrs)))
        (array/push edges @{:u u :v v :attrs attrs}))))

  @{:nodes nodes :edges edges})

(defn convert-coord [p orig-min orig-max new-min new-max]
  (def orig-size (- orig-max orig-min))
  (def new-size (- new-max new-min))
  (math/floor (+ (* (/ (- p orig-min) orig-size) new-size) new-min)))

(defn display [g layout]
  (def [stdout-r stdout-w] (os/pipe))

  (os/execute ["tput" "lines"] :p {:out stdout-w})
  (def num-rows (scan-number (string/trim (:read stdout-r 5) "\n")))

  (os/execute ["tput" "cols"] :p {:out stdout-w})
  (def num-cols (scan-number (string/trim (:read stdout-r 5) "\n")))

  (def grid (array))

  (loop [y :range [0 num-rows]]
    (do
      (def row (array))
      (loop [x :range [0 num-cols]]
        (array/push row ""))
      (array/push grid row)))

  (def nodes (get g :nodes))
  (def edges (get g :edges))

  (def boxes (get layout :nodes))
  (def paths (get layout :edges))

  (var min-x 1e10)
  (var max-x 0.0)
  (var min-y 1e10)
  (var max-y 0.0)

  (loop [i :range [0 (length nodes)]]
    (do
      (def box (get boxes i))
      (def x (get box :x))
      (def y (get box :y))
      (def w (get box :w))
      (def h (get box :h))
      (set min-x (min min-x x))
      (set max-x (max max-x (+ x w)))
      (set min-y (min min-y y))
      (set max-y (max max-y (+ y h)))))

  (loop [i :range [0 (length nodes)]]
    (do
      (def text (string/trim (get (get (get nodes i) :attrs) "label") "\\l"))
      (def lines (string/split "\\l" text))
      (pp lines)

      (def box (get boxes i))
      (def x (convert-coord (get box :x) min-x max-x 0 num-cols))
      (def y (convert-coord (get box :y) min-y max-y 0 num-rows))
      (def w (max (map length lines)))
      (def h (length lines))
      (pp x)
      (pp y)
      (pp w)
      (pp h)
      (pp "")))

  # (def row-strs (map (fn [row] (string/join row "")) grid))
  # (def result (string/join row-strs "\n"))
  # (print result)
)

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
  (display g layout)
)
