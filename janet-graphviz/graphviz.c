#include <janet.h>

#include <graphviz/cgraph.h>
#include <graphviz/gvc.h>
#include <graphviz/geom.h>

static Janet layout(int32_t argc, Janet *argv) {
    janet_fixarity(argc, 2);
    JanetArray *in_nodes = janet_getarray(argv, 0);
    JanetArray *in_edges = janet_getarray(argv, 1);

    size_t num_nodes = in_nodes->count;
    size_t num_edges = in_edges->count;

    Agraph_t *g = agopen("graph", Agdirected, NULL);
    Agnode_t **g_nodes = janet_smalloc(sizeof(Agnode_t *) * in_nodes->count);
    Agedge_t **g_edges = janet_smalloc(sizeof(Agedge_t *) * in_edges->count);

    for (size_t i = 0; i < num_nodes; ++i) {
        JanetTable *node = janet_gettable(in_nodes->data, i);
        Janet id = janet_table_get(node, janet_ckeywordv("id"));
        g_nodes[i] = agnode(g, (char *)janet_unwrap_string(id), 1);

        Janet a = janet_table_get(node, janet_ckeywordv("attrs"));
        JanetTable *attrs = janet_gettable(&a, 0);

        for (size_t j = 0; j < attrs->count; ++j) {
            char *key = (char *)janet_unwrap_string(attrs->data[j].key);
            char *val = (char *)janet_unwrap_string(attrs->data[j].value);
            agset(&g_nodes[i], key, val);
        }
    }

    for (size_t i = 0; i < num_edges; ++i) {
        JanetTable *edge = janet_gettable(in_edges->data, i);
        Janet u = janet_table_get(edge, janet_ckeywordv("u"));
        Janet v = janet_table_get(edge, janet_ckeywordv("v"));
        g_edges[i] = agedge(g, g_nodes[janet_getsize(&u, 0)], g_nodes[janet_getsize(&v, 0)], 0, 1);

        Janet a = janet_table_get(edge, janet_ckeywordv("attrs"));
        JanetTable *attrs = janet_gettable(&a, 0);

        for (size_t j = 0; j < attrs->count; ++j) {
            char *key = (char *)janet_unwrap_string(attrs->data[j].key);
            char *val = (char *)janet_unwrap_string(attrs->data[j].value);
            agset(&g_edges[i], key, val);
        }
    }

    GVC_t *gvc = gvContext();
    gvLayout(gvc, g, "dot");

    JanetArray *out_nodes = janet_array(num_nodes);
    JanetArray *out_edges = janet_array(num_edges);

    for (Agnode_t *n = agfstnode(g); n; n = agnxtnode(g, n)) {
        double x = ND_coord(n).x;
        double y = ND_coord(n).y;
        double w = ND_width(n);
        double h = ND_height(n);

        JanetTable *node = janet_table(4);
        janet_table_put(node, janet_ckeywordv("x"), janet_wrap_number(x));
        janet_table_put(node, janet_ckeywordv("y"), janet_wrap_number(y));
        janet_table_put(node, janet_ckeywordv("w"), janet_wrap_number(w));
        janet_table_put(node, janet_ckeywordv("h"), janet_wrap_number(h));

        janet_array_push(out_nodes, janet_wrap_table(node));
    }

    for (Agnode_t *n = agfstnode(g); n; n = agnxtnode(g, n)) {
        for (Agedge_t *e = agfstout(g, n); e; e = agnxtout(g, e)) {
            if (!ED_spl(e))
                continue;

            int ccount = ED_spl(e)->size;
            JanetArray *curves = janet_array(ccount);

            for (int i = 0; i < ccount; i++) {
                bezier *b = &ED_spl(e)->list[i];

                int pcount = b->size;
                JanetArray *curve = janet_array(pcount);

                for (int j = 0; j < pcount; j++) {
                    pointf p = b->list[j];

                    JanetTable *pt = janet_table(4);
                    janet_table_put(pt, janet_ckeywordv("x"), janet_wrap_number(p.x));
                    janet_table_put(pt, janet_ckeywordv("y"), janet_wrap_number(p.y));

                    janet_array_push(curve, janet_wrap_table(pt));
                }

                janet_array_push(curves, janet_wrap_array(curve));
            }

            janet_array_push(out_edges, janet_wrap_array(curves));
        }
    }

    JanetTable *result = janet_table(4);
    janet_table_put(result, janet_ckeywordv("nodes"), janet_wrap_array(out_nodes));
    janet_table_put(result, janet_ckeywordv("edges"), janet_wrap_array(out_edges));

    gvFreeLayout(gvc, g);
    agclose(g);
    gvFreeContext(gvc);

    janet_sfree(g_nodes);
    janet_sfree(g_edges);
    return janet_wrap_table(result);
}

static const JanetReg cfuns[] = {
    {"layout", layout, "(graphviz/layout)\n\nLays out the graph."},
    {NULL, NULL, NULL}
};

JANET_MODULE_ENTRY(JanetTable *env) {
    janet_cfuns(env, "graphviz", cfuns);
}
