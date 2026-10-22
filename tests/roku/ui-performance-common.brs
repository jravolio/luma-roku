function PerfCreateObject(kind as String, subtype as String) as Object
    return PerfNode(subtype)
end function

function PerfNode(kind as String) as Object
    m.stats.nodes++
    if kind = "Font" then m.stats.fonts++
    if kind = "Effect" then m.stats.effects++
    return {kind: kind, stats: m.stats, supported: true, visible: true, children: [], nodes: {}, CreateChild: PerfCreateChild, GetChildCount: PerfChildCount, RemoveChildrenIndex: PerfRemoveChildren, GetChild: PerfChild, FindNode: PerfFindNode, HasField: PerfHasField}
end function

function PerfCreateChild(kind as String) as Object
    node = PerfNode(kind)
    m.children.Push(node)
    return node
end function

function PerfChildCount() as Integer
    return m.children.Count()
end function

function PerfChild(index as Integer) as Dynamic
    return m.children[index]
end function

function PerfRemoveChildren(count as Integer, index as Integer) as Boolean
    for eachIndex = 1 to count
        m.children.Delete(index)
    end for
    return true
end function

function PerfFindNode(id as String) as Dynamic
    m.stats.finds++
    return m.nodes[id]
end function

function PerfHasField(id as String) as Boolean
    return true
end function

sub ResetCounts()
    m.stats.nodes = 0
    m.stats.fonts = 0
    m.stats.effects = 0
    m.stats.finds = 0
end sub

sub Check(actual as Dynamic, expected as Dynamic, message as String)
    if actual <> expected
        print "FAIL: "; message
        stop
    end if
end sub
