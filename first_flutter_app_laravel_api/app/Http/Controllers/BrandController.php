<?php

namespace App\Http\Controllers;

use App\Models\Brand;
use Illuminate\Http\Request;

class BrandController extends Controller
{
    public function index(Request $request)
    {
        return Brand::where('category_id', $request->category_id)->get();
    }

    public function store(Request $request)
    {
        $brand = Brand::create([
            'category_id' => $request->category_id,
            'name' => $request->name,
        ]);

        return $brand;
    }

    public function update(Request $request, $id)
    {
        $brand = Brand::findOrFail($id);

        $brand->update([
            'name' => $request->name,
        ]);

        return $brand;
    }

    public function destroy($id)
    {
        $brand = Brand::findOrFail($id);

        $brand->delete();

        return response()->json([
            'message' => 'Brand deleted successfully'
        ]);
    }
}
