IFDEF __DEBUG__, ->
  
  DEFINE TEST_FUN, (a) -> console.log "olololololo"
  DEFINE TEST_OBJ, {test1: TEST_DEFINE, test2: 123, f: TEST_FUN}
  console.log '__DEBUG__', TEST_FUN, DEFINE
  console.log '__DEBUG__', TEST_FUN, DEFINE
  console.log '__DEBUG__', TEST_FUN, DEFINE