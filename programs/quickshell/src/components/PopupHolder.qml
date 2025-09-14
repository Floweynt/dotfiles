import QtQuick

Item {
    // this is a quite a complex class in terms of the animation queuing logic

    // in general, there are 3 states to this object:
    // - empty
    // - visible 
    // - closing
    //
    // we can queue the opening of an entry via 
    // queueOpen(element, callback)
    //
    // we can aler
    // notifyClose()
    //
    property Item activeItem
}
