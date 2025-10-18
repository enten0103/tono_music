/**
 * @name 野花🌷
 * @version 1.0.0
 */
function O() {
    const R = ["3934685EJsypn", "4155220shjmqd", "code", "hash", "copyrightI", "GET", "hex", "gSyEM", "4009336twNHZx", "QTdcX", "vMIuN", "acGOz", "iamzW", "kw|128k&wy", "/url/", "nNhDn", "bufToStrin", "119924Zhuara", "lx-music/", "stringify", "wer.tempmu", "data", "QVjzE", "/urlinfo/", "musicUrl", "1510707iVmAso", "md5", "CxlIL", "match", "request", "959116lEWWZC", "songmid", "sources", "http://flo", "buffer", "14NoiTNH", "split", "5159PfWaop", "inited", "DFjbN", "|128k&mg|1", "sics.tk/v1", "10878XneaKF", "tag", "from", "KEWEM", "3MhKFyJ", "wrDDF", "QXcEI", "uITgx", "28k&tx|128", "ILkJK", "FhkNH", "crypto", "服务器异常", "failed", "FpTmP", "156KGDOun", "msg", "fialed", "body", "k&kg|128k", "LCTQX", "shift", "PkJlH", "xTmgg", "music", "rawScript", "9WQyvje", "version", "updateAler", "trim", "lecSG"];
    O = function () {
        return R;
    };
    return O();
}
function Z(Y, L) {
    const K = O();
    Z = function (U, H) {
        U = U - 345;
        let S = K[U];
        return S;
    };
    return Z(Y, L);
}
const k = Z;

const {
    EVENT_NAMES: e,
    request: t,
    on: r,
    send: o,
    env: s,
    version: d,
    currentScriptInfo: i,
    utils: u
} = globalThis.lx;
const getId = (Y, L) => {
    const I = Z;
    const K = {
        wrDDF: function (U, H) {
            return U(H);
        },
        uITgx: I(365)
    };
    switch (Y) {
        case "tx":
        case "wy":
        case "kw":
            return L[I("0x19e")];
        case "kg":
            return L[I(386)];
        case "mg":
            return L[I("0x183") + "d"];
    }
    throw K[I("0x165")](Error, K[I(359)]);
};
const headers = {
    "User-Agent": k(401) + s,
    ver: d,
    "source-ver": i[k("0x17b")]
};
r(e[k("0x19c")], ({
    source: Y,
    action: L,
    info: {
        musicInfo: K,
        type: U
    }
}) => {
    const x = k;
    const H = {
        vMIuN: function (S, N, B) {
            return S(N, B);
        },
        QXcEI: x(389),
        LCTQX: function (S, N, B, v) {
            return S(N, B, v);
        },
        iamzW: function (S, N) {
            return S + N;
        },
        PkJlH: x("0x1a0") + x(403) + x("0x15f"),
        nNhDn: x("0x184"),
        QTdcX: function (S, N) {
            return S != N;
        },
        acGOz: x(407),
        DFjbN: function (S, N) {
            return S(N);
        },
        ILkJK: x(369)
    };
    if (H[x(392)](H[x("0x18a")], L)) {
        throw H[x("0x15d")](Error, H[x("0x169")]);
    }
    return new Promise((S, N) => {
        const c = x;
        let B = c("0x18d") + Y + "/" + H[c("0x189")](getId, Y, K) + "/" + U;
        headers[c(353)] = u[c(417)][c("0x18f") + "g"](u[c("0x1a1")][c(354)](JSON[c(402)](B[c(411)](/(?:\d\w)+/g), null, 1)), H[c("0x166")]);
        H[c(372)](t, H[c(395)](H[c(374)], B), {
            method: H[c("0x18e")],
            headers: headers
        }, (v, G) => v ? N(v) : G[c(370)][c("0x181")] !== 0 ? N(Error(G[c(370)][c(368)])) : void S(G[c("0x172")][c("0x194")]));
    });
});
t(k("0x1a0") + k("0x193") + k(351) + k("0x196") + i[k("0x17b")], {
    method: k("0x184"),
    headers: headers
}, (U, H) => {
    const a = k;
    const S = {
        lecSG: a("0x18c") + a(350) + a("0x168") + a(371),
        KEWEM: function (M, T) {
            return M !== T;
        },
        CxlIL: function (M, T) {
            return M != T;
        },
        xTmgg: function (M, T) {
            return M(T);
        },
        FhkNH: a("0x16c"),
        gSyEM: a(376),
        QVjzE: a("0x197"),
        FpTmP: function (M, T, E) {
            return M(T, E);
        }
    };
    const N = {
        [a("0x181")]: 0
    };
    N.s = S[a("0x17e")];
    const B = {
        [a(370)]: N
    };
    if (U) {
        H = B;
    }
    if (S[a("0x163")](0, H[a(370)][a("0x181")]) || H[a(370)].m && S[a("0x19a")](u[a("0x16b")][a("0x199")](i[a(377)][a(381)]()), H[a(370)].m)) {
        throw S[a(375)](Error, H[a("0x172")][a("0x170")] ?? S[a(362)]);
    }
    let v = {};
    for (let M of H[a(370)].s[a("0x17d")]()[a("0x15a")]("&")) {
        v[(M = M[a(346)]("|"))[a("0x175")]()] = {
            type: S[a("0x186")],
            actions: [S[a(405)]],
            qualitys: M
        };
    }
    const G = {
        [a("0x19f")]: v
    };
    S[a(366)](o, e[a(348)], G);
    if (H[a("0x172")].u) {
        S[a(366)](o, e[a(380) + "t"], {
            log: H[a(370)].u,
            updateUrl: H[a("0x172")].h
        });
    }
});