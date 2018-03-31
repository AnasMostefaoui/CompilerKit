struct Grammar<T: Hashable> {
    enum Node<T: Hashable>: Hashable {
        case nt(Int)
        case t(T)
        case empty
    }
    
    var productions: [[[Node<T>]]]
    let rootTerm: Int
    let eof: T
    
    mutating func eliminateLeftRecursion() {
        for i in 0..<productions.count {
            if i > 0 {
                // find productions starting with a preceeding NT
                // as they could lead to indirect left recursion
                for j in 0..<i {
                    for p in 0..<productions[i].count {
                        if productions[i][p].first == .nt(j) {
                            // replace the potentially problematic first NT
                            // with all of its possible productions
                            let tail = productions[i][p][1...]
                            productions[i][p] = productions[j].first! + tail
                            for sub in productions[j][1...] {
                                productions[i].append(sub + tail)
                            }
                        }
                    }
                }
            }
            
            // eliminate direct left recursion
            if productions[i].contains(where: { $0.first == .nt(i) }) {
                let newNt = productions.count
                productions.append([[.empty]])
                let current = productions[i]
                productions[i] = []
                for p in current {
                    if p.first == .nt(i) {
                        productions[newNt].append(p[1...] + [.nt(newNt)])
                    } else {
                        productions[i].append(p + [.nt(newNt)])
                    }
                }
            }
        }
    }
    
    var first: ([[T: Set<Int>]], [Bool]) {
        var first: [[T: Set<Int>]] = Array(repeating: [:], count: productions.count)
        var canBeEmpty = Array(repeating: false, count: productions.count)
        
        func firstByNode(_ n: Node<T>) -> Set<T> {
            switch n {
            case let .t(t): return Set([t])
            case let .nt(nt): return Set(first[nt].keys)
            case .empty: return Set()
            }
        }
        
        func canBeEmptyByNode(_ n: Node<T>) -> Bool {
            switch n {
            case .t(_): return false
            case let .nt(nt): return canBeEmpty[nt]
            case .empty: return true
            }
        }
        
        var changing = true
        while changing {
            changing = false
            for s in 0..<productions.count {
                for (pIdx, p) in productions[s].enumerated() {
                    var rhs: Set<T> = firstByNode(p.first!)
                    var i = 0
                    while canBeEmptyByNode(p[i]) && i < p.count - 1 {
                        rhs.formUnion(firstByNode(p[i]))
                        i += 1
                    }
                    
                    if i == p.count - 1 && canBeEmptyByNode(p[i]) {
                        if !canBeEmpty[s] {
                            canBeEmpty[s] = true
                            changing = true
                        }
                    }
                    
                    let beforeUpdate = first[s]
                    for t in rhs {
                        first[s][t, default: []].insert(pIdx)
                    }
                    changing = changing || first[s] != beforeUpdate
                }
            }
        }
        
        return (first, canBeEmpty)
    }
    
    var follow: [Set<T>] {
        var (first, canBeEmpty) = self.first
        var follow = Array(repeating: Set<T>(), count: productions.count)
        follow[rootTerm].insert(eof)
        
        var changing = true
        while changing {
            changing = false
            for s in 0..<productions.count {
                for p in productions[s] {
                    var trailer = follow[s]
                    for n in p.reversed() {
                        switch n {
                        case let .nt(nt):
                            let beforeUpdate = follow[nt]
                            follow[nt].formUnion(trailer)
                            if follow[nt] != beforeUpdate { changing = true }
                            
                            if canBeEmpty[nt] {
                                trailer.formUnion(first[nt].keys)
                            } else {
                                trailer = Set(first[nt].keys)
                            }
                        case let .t(t): trailer = [t]
                        case .empty: trailer = []
                        }
                    }
                }
            }
        }
        
        return follow
    }
}

