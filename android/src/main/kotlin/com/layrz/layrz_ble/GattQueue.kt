package com.layrz.layrz_ble

import io.flutter.Log
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Serializes Android BLE GATT operations so only one is in-flight at a time.
 *
 * Android's BluetoothGatt rejects (returns false) any operation if another is
 * already pending. This queue ensures each operation waits for the previous
 * one to complete before executing.
 *
 * Usage:
 *  1. Call `enqueue { ... }` to schedule a GATT operation.  The lambda
 *     receives a `GattCompletion` callback; the caller **must** invoke
 *     `completion.done()` when the GATT callback fires (success or failure).
 *  2. Call `clear()` on disconnect to cancel all pending operations.
 */
class GattQueue(private val tag: String = "GattQueue") {

    /** Handle passed to each queued operation; call [done] from the GATT callback. */
    class GattCompletion internal constructor(private val channel: Channel<Unit>) {
        private var completed = false

        fun done() {
            if (!completed) {
                completed = true
                channel.trySend(Unit)
            }
        }
    }

    private data class QueueEntry(
        val label: String,
        val block: (GattCompletion) -> Unit
    )

    private val queue = ConcurrentLinkedQueue<QueueEntry>()
    private var running = false
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    /**
     * Enqueue a GATT operation.
     *
     * @param label  Short description for logging (e.g. "readCharacteristic").
     * @param block  Lambda that starts the GATT operation.  It receives a
     *               [GattCompletion] that **must** be called when the operation
     *               finishes (from the GATT callback, timeout handler, or error
     *               path).
     */
    fun enqueue(label: String, block: (GattCompletion) -> Unit) {
        Log.d(tag, "enqueue: $label (queue size=${queue.size}, running=$running)")
        queue.add(QueueEntry(label, block))
        drainNext()
    }

    /** Cancel all pending operations and reset state. Call on disconnect. */
    fun clear() {
        Log.d(tag, "clear: dropping ${queue.size} pending operations")
        queue.clear()
        running = false
    }

    private fun drainNext() {
        if (running) return
        val entry = queue.poll() ?: return

        running = true
        Log.d(tag, "executing: ${entry.label} (remaining=${queue.size})")

        val completionChannel = Channel<Unit>(1)
        val completion = GattCompletion(completionChannel)

        scope.launch {
            try {
                // Run the GATT operation on Main thread
                entry.block(completion)

                // Wait for the GATT callback to signal completion, with a
                // safety net timeout so the queue never gets permanently stuck.
                withTimeoutOrNull(60_000L) {
                    completionChannel.receive()
                } ?: run {
                    Log.d(tag, "safety timeout: ${entry.label} did not complete in 60s")
                }
            } catch (e: Exception) {
                Log.d(tag, "error in ${entry.label}: ${e.message}")
            } finally {
                running = false
                drainNext()
            }
        }
    }
}
