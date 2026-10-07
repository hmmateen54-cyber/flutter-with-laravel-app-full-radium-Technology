<?php

namespace App\Http\Controllers;

use App\Models\Todo;
use Illuminate\Http\Request;

class TodoController extends Controller
{
    public function index(){
        return Todo::all();
    }

    public function store(Request $request){
        $todo = Todo::create(
            [
                'title' => $request->title,
            ]
        );
        return $todo;
    }
}
