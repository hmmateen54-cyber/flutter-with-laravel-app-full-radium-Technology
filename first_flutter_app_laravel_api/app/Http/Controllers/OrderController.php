<?php

namespace App\Http\Controllers;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OrderController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'product_id' => 'required|exists:products,id',
            'quantity' => 'required|integer|min:1',
            'customer_name' => 'required|string',
            'phone' => 'required|string',
            'address' => 'required|string',
            'city' => 'required|string',
        ]);

        $product = Product::findOrFail(
            $request->product_id
        );

        $totalAmount =
            $product->price * $request->quantity;

        DB::transaction(function () use (
            $request,
            $product,
            $totalAmount
        ) {

            $order = Order::create([
                'user_id' => $request->user()->id,
                'customer_name' => $request->customer_name,
                'phone' => $request->phone,
                'address' => $request->address,
                'city' => $request->city,
                'total_amount' => $totalAmount,
                'status' => 'pending',
            ]);

            OrderItem::create([
                'order_id' => $order->id,
                'product_id' => $product->id,
                'quantity' => $request->quantity,
                'price' => $product->price,
            ]);
        });

        return response()->json([
            'message' => 'Order placed successfully',
        ], 201);
    }

    public function myOrders(Request $request)
    {
        $orders = Order::with('items.product')
            ->where('user_id', $request->user()->id)
            ->latest()
            ->get();

        return $orders;
    }

    public function allOrders()
    {
        return Order::with('items.product')
            ->latest()
            ->get();
    }

    public function updateStatus(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:pending,confirmed,processing,dispatched,delivered,cancelled',
        ]);

        $order = Order::findOrFail($id);

        $order->update([
            'status' => $request->status,
        ]);

        return response()->json([
            'message' => 'Order status updated successfully',
            'order' => $order,
        ]);
    }
}