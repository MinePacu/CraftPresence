package com.minepacu.craftpresence.core.util

class LruMemoryCache<K, V>(private val capacity: Int) {
    private val map = object : LinkedHashMap<K, V>(capacity.coerceAtLeast(1), 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<K, V>?): Boolean {
            return size > capacity.coerceAtLeast(1)
        }
    }

    @Synchronized fun get(key: K): V? = map[key]

    @Synchronized fun put(key: K, value: V) {
        map[key] = value
    }

    @Synchronized fun clear() {
        map.clear()
    }
}
