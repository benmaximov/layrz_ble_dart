@file:Suppress("SpellCheckingInspection")

package com.layrz.layrz_ble

import android.os.ParcelUuid
import java.util.UUID

fun standarizeUuid(uuid: UUID): String {
    return uuid.toString().uppercase()
}

fun castServiceUuid(uuid: UUID): Int {
    val shortUuid = uuid.toString().substring(4, 8)
    return Integer.parseInt(shortUuid, 16)
}