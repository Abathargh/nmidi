import unittest

import nmidi

type SimpleReader = distinct uint8

proc read(s: SimpleReader): uint8 =
  cast[uint8](s)

suite "read midi":
  test "basic read":
    const sreader = SimpleReader(0x8a)
    var act: MidiAction
    check sreader.getMidiAction(act) == true
    check act.st == NoteOff
    check act.channel == 0xa
    check act.offNote == 0x8a
    check act.offVelocity == 0x8a
