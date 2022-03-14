//
//  Queue.swift
//  flutter_ble_lib
//
//  Created by Olivér Kocsis on 21/05/2021.
//

import Foundation

struct Queue<T> {
  private var leftStack: [T] = []
  private var rightStack: [T] = []
  
  var isEmpty: Bool {
    leftStack.isEmpty && rightStack.isEmpty
  }
  var peek: T? {
    leftStack.isEmpty ? rightStack.first : leftStack.last
  }
  mutating func enqueue(_ element: T) {
      rightStack.append(element)
  }
  mutating func dequeue() -> T? {
    if isEmpty {
      return nil
    }
    if leftStack.isEmpty {
      leftStack = rightStack.reversed()
      rightStack.removeAll()
    }
    
    return leftStack.removeLast()
  }
}

extension Queue: CustomStringConvertible {
  var description: String {
    
    if isEmpty {
      return "Queue is empty..."
    }
    var allElements: [T] = []
    if leftStack.isEmpty == false {
      allElements.append(contentsOf: leftStack.reversed())
    }
    allElements.append(contentsOf: rightStack)
    
    return "---- Queue start ----\n"
      + allElements.map({"\($0)"}).joined(separator: " -> ")
      + "\n---- Queue End ----"
  }
}


