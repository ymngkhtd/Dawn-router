import assert from 'node:assert/strict'
import { describe, test } from 'bun:test'

import {
  convertDetectedLanguage,
  normalizeInterfaceLanguage,
} from '../languages'

describe('interface language normalization', () => {
  test('maps legacy simplified Chinese values to zhCN', () => {
    assert.equal(normalizeInterfaceLanguage('zh'), 'zhCN')
    assert.equal(normalizeInterfaceLanguage('zh-CN'), 'zhCN')
    assert.equal(normalizeInterfaceLanguage('zhCN'), 'zhCN')
  })

  test('maps detected Chinese locales to the matching interface language', () => {
    assert.equal(convertDetectedLanguage('zh'), 'zhCN')
    assert.equal(convertDetectedLanguage('zh-CN'), 'zhCN')
    assert.equal(convertDetectedLanguage('zh-TW'), 'zhTW')
  })
})
