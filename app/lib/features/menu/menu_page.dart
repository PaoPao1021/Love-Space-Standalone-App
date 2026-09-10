import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../together/together_models.dart';
import '../together/together_repository.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({required this.repository, super.key});
  final TogetherRepository repository;

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _search = TextEditingController();
  final List<DishOrderDraft> _cart = [];
  final Map<String, Dish> _knownDishes = {};
  String _orderRequestId = TogetherRepository.requestId('order');
  String _category = '';
  bool _busy = false;
  late Future<List<Dish>> _dishes = _loadDishes();
  late Future<List<MenuOrder>> _orders = widget.repository.orders();

  Future<List<Dish>> _loadDishes() async {
    final dishes = await widget.repository.dishes(
      keyword: _search.text,
      category: _category,
    );
    for (final dish in dishes) {
      _knownDishes[dish.id] = dish;
    }
    return dishes;
  }

  void _reloadDishes() => setState(() => _dishes = _loadDishes());
  void _reloadOrders() => setState(() => _orders = widget.repository.orders());

  Future<void> _addDish([Dish? existing]) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _DishEditor(repository: widget.repository, existing: existing),
    );
    if (created == true) _reloadDishes();
  }

  Future<void> _manageCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategoryManager(repository: widget.repository),
    );
    _reloadDishes();
  }

  Future<void> _recommend() async {
    try {
      final dishes = await widget.repository.recommendations();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('今天可以吃'),
          content: dishes.isEmpty
              ? const Text('先收藏几道评分 4 分以上的菜吧。')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: dishes
                      .map(
                        (dish) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.restaurant_outlined),
                          title: Text(dish.name),
                          subtitle: Text(
                            '${dish.category} · ${_money(dish.price)}',
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _increaseDish(dish);
                          },
                        ),
                      )
                      .toList(),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _dishAction(Dish dish, String action) async {
    try {
      if (action == 'eaten') {
        await widget.repository.markDishEaten(dish.id);
      } else if (action == 'edit') {
        await _addDish(dish);
      } else if (action == 'delete') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('删除菜品？'),
            content: Text('“${dish.name}”会从你们的菜单中移除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await widget.repository.deleteDish(dish.id);
        _cart.removeWhere((item) => item.dishId == dish.id);
      }
      _reloadDishes();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _placeOrder() async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认点菜'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_cartCount()} 份 · ${_money(_cartTotal())}'),
            const SizedBox(height: 14),
            TextField(
              controller: note,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '给 TA 留句话（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再看看'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认下单'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      note.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.placeOrder(
        List.unmodifiable(_cart),
        note.text,
        requestId: _orderRequestId,
      );
      _cart.clear();
      _orderRequestId = TogetherRepository.requestId('order');
      _reloadOrders();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('订单已同步给 TA')));
        _tabs.animateTo(1);
      }
    } catch (error) {
      _showError(error);
    } finally {
      note.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  int _cartCount() => _cart.fold(0, (total, item) => total + item.quantity);

  int _dishQuantity(String dishId) => _cart
      .where((item) => item.dishId == dishId)
      .fold(0, (total, item) => total + item.quantity);

  double _cartTotal() => _cart.fold(0, (total, item) {
    final dish = _knownDishes[item.dishId];
    if (dish == null) return total;
    return total +
        (dish.price + _specPrice(dish, item.selectedSpecs)) * item.quantity;
  });

  double _specPrice(Dish dish, Map<String, String> selected) => dish.specs.fold(
    0,
    (total, group) =>
        total +
        group.options
            .where((option) => option.name == selected[group.name])
            .fold(0, (sum, option) => sum + option.priceAdd),
  );

  Future<void> _increaseDish(Dish dish) async {
    if (!dish.available) return;
    Map<String, String> selected = const {};
    if (dish.specs.isNotEmpty) {
      final result = await _chooseSpecs(dish);
      if (result == null || !mounted) return;
      selected = result;
    }
    setState(() {
      final index = _cart.indexWhere(
        (item) =>
            item.dishId == dish.id && _sameSpecs(item.selectedSpecs, selected),
      );
      if (index < 0) {
        _cart.add(
          DishOrderDraft(dishId: dish.id, quantity: 1, selectedSpecs: selected),
        );
      } else {
        _cart[index] = _cart[index].copyWith(
          quantity: (_cart[index].quantity + 1).clamp(1, 99),
        );
      }
    });
  }

  void _decreaseDish(Dish dish) {
    final index = _cart.lastIndexWhere((item) => item.dishId == dish.id);
    if (index < 0) return;
    setState(() {
      final next = _cart[index].quantity - 1;
      if (next <= 0) {
        _cart.removeAt(index);
      } else {
        _cart[index] = _cart[index].copyWith(quantity: next);
      }
    });
  }

  bool _sameSpecs(Map<String, String> left, Map<String, String> right) =>
      left.length == right.length &&
      left.entries.every((entry) => right[entry.key] == entry.value);

  Future<Map<String, String>?> _chooseSpecs(Dish dish) {
    final selected = <String, String>{
      for (final group in dish.specs)
        if (group.options.isNotEmpty) group.name: group.options.first.name,
    };
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('选择 ${dish.name} 的规格'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: dish.specs
                  .map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: group.options
                                .map(
                                  (option) => ChoiceChip(
                                    label: Text(
                                      option.priceAdd > 0
                                          ? '${option.name} +${_money(option.priceAdd)}'
                                          : option.name,
                                    ),
                                    selected:
                                        selected[group.name] == option.name,
                                    onSelected: (_) => setDialogState(
                                      () => selected[group.name] = option.name,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, Map.of(selected)),
              child: const Text('加入菜单'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCart() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('已选菜品', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ..._cart.map((item) {
          final dish = _knownDishes[item.dishId];
          if (dish == null) return const SizedBox.shrink();
          final specText = item.selectedSpecs.values.join(' / ');
          return ListTile(
            title: Text(dish.name),
            subtitle: specText.isEmpty ? null : Text(specText),
            trailing: Text(
              '${item.quantity} × ${_money(dish.price + _specPrice(dish, item.selectedSpecs))}',
            ),
          );
        }),
      ],
    ),
  );

  Future<void> _showOrderMode() async {
    final dishes = await widget.repository.dishes();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .72,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '想吃什么？点TA做',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: dishes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final dish = dishes[index];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: const Color(0xFFF7F2ED),
                    leading: const Text('🍽️', style: TextStyle(fontSize: 24)),
                    title: Text(dish.name),
                    subtitle: Text(
                      '${dish.category} · ${dish.rating.toStringAsFixed(0)}⭐',
                    ),
                    trailing: const Icon(Icons.add_circle_outline_rounded),
                    onTap: () async {
                      await _increaseDish(dish);
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: _cartCount() == 0
                    ? null
                    : () {
                        Navigator.pop(context);
                        _showCart();
                      },
                child: Text(
                  _cartCount() == 0 ? '选择菜品后下单' : '查看已选 ${_cartCount()} 份',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('今天吃什么'),
      actions: [
        IconButton(
          tooltip: '随机推荐',
          onPressed: _busy ? null : _recommend,
          icon: const Icon(Icons.casino_outlined),
        ),
        IconButton(
          tooltip: '添加菜品',
          onPressed: _busy ? null : _addDish,
          icon: const Icon(Icons.add_rounded),
        ),
        IconButton(
          tooltip: '管理菜单分类',
          onPressed: _busy ? null : _manageCategories,
          icon: const Icon(Icons.category_outlined),
        ),
      ],
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: '菜单'),
          Tab(text: '订单记录'),
        ],
      ),
    ),
    body: SafeArea(
      child: TabBarView(
        controller: _tabs,
        children: [_menuTab(), _ordersTab()],
      ),
    ),
  );

  Widget _menuTab() => FutureBuilder<List<Dish>>(
    future: _dishes,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: OutlinedButton(
            onPressed: _reloadDishes,
            child: const Text('加载失败，点按重试'),
          ),
        );
      }
      final dishes = snapshot.data ?? const [];
      final categories = dishes.map((dish) => dish.category).toSet().toList()
        ..sort();
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  _reloadDishes();
                  await _dishes;
                },
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    28,
                    14,
                    28,
                    _cartCount() > 0 ? 118 : 24,
                  ),
                  children: [
                    InkWell(
                      onTap: _showOrderMode,
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE85D75), Color(0xFFF08A9B)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Text('👨‍🍳', style: TextStyle(fontSize: 28)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '想吃什么？点TA做',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    '选好发给TA，让TA给你做~',
                                    style: TextStyle(
                                      color: Color(0xDDFFFFFF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '›',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _recommend,
                            icon: const Text('🤔'),
                            label: const Text('随机推荐'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addDish,
                            icon: const Text('➕'),
                            label: const Text('添加菜品'),
                          ),
                        ),
                      ],
                    ),
                    if (categories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('🍽️ 全部'),
                              selected: _category.isEmpty,
                              onSelected: (_) {
                                _category = '';
                                _reloadDishes();
                              },
                            ),
                            const SizedBox(width: 8),
                            ...categories.map(
                              (value) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text('🍽️ $value'),
                                  selected: _category == value,
                                  onSelected: (_) {
                                    _category = value;
                                    _reloadDishes();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (dishes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(36),
                        child: Column(
                          children: [
                            Icon(Icons.restaurant_menu_outlined, size: 56),
                            SizedBox(height: 14),
                            Text('菜单还是空的，先加一道喜欢的菜'),
                          ],
                        ),
                      )
                    else
                      ...dishes.map(
                        (dish) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DishCard(
                            dish: dish,
                            quantity: _dishQuantity(dish.id),
                            onDecrease: () => _decreaseDish(dish),
                            onIncrease: () => _increaseDish(dish),
                            onAction: (action) => _dishAction(dish, action),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_cartCount() > 0)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Card(
                    elevation: 5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_cartCount()} 份 · ${_money(_cartTotal())}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showCart,
                            child: const Text('查看'),
                          ),
                          FilledButton(
                            onPressed: _busy ? null : _placeOrder,
                            child: Text(_busy ? '正在下单…' : '选好了'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _ordersTab() => FutureBuilder<List<MenuOrder>>(
    future: _orders,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: OutlinedButton(
            onPressed: _reloadOrders,
            child: const Text('加载失败，点按重试'),
          ),
        );
      }
      final orders = snapshot.data ?? const [];
      if (orders.isEmpty) return const Center(child: Text('还没有点菜记录'));
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: () async {
              _reloadOrders();
              await _orders;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (_, index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OrderCard(order: orders[index]),
              ),
            ),
          ),
        ),
      );
    },
  );

  static String _money(double value) => value == value.roundToDouble()
      ? '¥${value.toStringAsFixed(0)}'
      : '¥${value.toStringAsFixed(2)}';
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.dish,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAction,
  });
  final Dish dish;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 54,
              height: 54,
              child: dish.imageUrl.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFF7F2ED),
                      child: Center(
                        child: Text('🍽️', style: TextStyle(fontSize: 25)),
                      ),
                    )
                  : Image.network(
                      dish.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFF7F2ED),
                        child: Center(child: Text('🍽️')),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dish.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '菜品操作',
                      onSelected: onAction,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑菜品')),
                        PopupMenuItem(value: 'eaten', child: Text('今天吃过了')),
                        PopupMenuItem(value: 'delete', child: Text('删除菜品')),
                      ],
                    ),
                  ],
                ),
                Text(
                  '${dish.category} · ${dish.rating.toStringAsFixed(0)}⭐',
                  style: const TextStyle(
                    color: Color(0xFFA05A67),
                    fontSize: 12,
                  ),
                ),
                if (dish.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    dish.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: '减少数量',
                      onPressed: quantity == 0 ? null : onDecrease,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    Semantics(
                      label: '已选 $quantity 份',
                      child: Text('$quantity'),
                    ),
                    IconButton(
                      tooltip: '增加数量',
                      onPressed: dish.available ? onIncrease : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class MenuPageStateMoney {
  static String value(double amount) => amount == amount.roundToDouble()
      ? '¥${amount.toStringAsFixed(0)}'
      : '¥${amount.toStringAsFixed(2)}';
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final MenuOrder order;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${order.createdAt.month} 月 ${order.createdAt.day} 日',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                MenuPageStateMoney.value(order.totalPrice),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...order.items.map(
            (item) => Text(
              '${item.name}${item.specText.isEmpty ? '' : '（${item.specText}）'} × ${item.quantity}',
            ),
          ),
          if (order.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(order.note, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    ),
  );
}

class _DishEditor extends StatefulWidget {
  const _DishEditor({required this.repository, this.existing});
  final TogetherRepository repository;
  final Dish? existing;
  @override
  State<_DishEditor> createState() => _DishEditorState();
}

class _DishEditorState extends State<_DishEditor> {
  final String _requestId = TogetherRepository.requestId('dish');
  final _name = TextEditingController();
  final _category = TextEditingController(text: '主食');
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  final _note = TextEditingController();
  final _location = TextEditingController();
  final List<_SpecDraft> _specs = [];
  Uint8List? _imageBytes;
  String _imageName = '';
  bool _removeImage = false;
  bool _available = true;
  double _rating = 5;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    if (item != null) {
      _name.text = item.name;
      _category.text = item.category;
      _price.text = item.price.toString();
      _description.text = item.description;
      _tags.text = item.tags.join(' ');
      _note.text = item.note;
      _location.text = item.location;
      _available = item.available;
      _specs.addAll(item.specs.map(_SpecDraft.fromModel));
      _rating = item.rating;
    }
  }

  Future<void> _chooseImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = image.name;
      _removeImage = false;
    });
  }

  void _addSpecGroup() => setState(() => _specs.add(_SpecDraft.empty()));

  void _removeSpecGroup(int index) {
    setState(() => _specs.removeAt(index).dispose());
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    String uploadedAsset = '';
    try {
      if (_imageBytes != null) {
        uploadedAsset = await widget.repository.uploadDishImage(
          _imageBytes!,
          _imageName,
        );
      }
      final specs = _specs
          .map((draft) => draft.toModel())
          .where((group) => group.name.isNotEmpty && group.options.isNotEmpty)
          .take(10)
          .toList();
      if (widget.existing == null) {
        final duplicated = await widget.repository.addDish(
          requestId: _requestId,
          name: _name.text,
          category: _category.text,
          price: double.tryParse(_price.text) ?? 0,
          rating: _rating.round(),
          description: _description.text,
          tags: _tags.text,
          note: _note.text,
          location: _location.text,
          available: _available,
          imageAssetId: uploadedAsset,
          specs: specs,
        );
        if (duplicated && uploadedAsset.isNotEmpty) {
          await widget.repository.deleteAsset(uploadedAsset);
          uploadedAsset = '';
        }
      } else {
        await widget.repository.updateDish(
          id: widget.existing!.id,
          name: _name.text,
          category: _category.text,
          price: double.tryParse(_price.text) ?? 0,
          rating: _rating.round(),
          description: _description.text,
          tags: _tags.text,
          note: _note.text,
          location: _location.text,
          available: _available,
          imageAssetId: uploadedAsset.isNotEmpty
              ? uploadedAsset
              : _removeImage
              ? ''
              : null,
          specs: specs,
        );
        final previous = widget.existing!.imageAssetId;
        if ((uploadedAsset.isNotEmpty || _removeImage) && previous.isNotEmpty) {
          await widget.repository.deleteAsset(previous);
        }
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (uploadedAsset.isNotEmpty) {
        try {
          await widget.repository.deleteAsset(uploadedAsset);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _price.dispose();
    _description.dispose();
    _tags.dispose();
    _note.dispose();
    _location.dispose();
    for (final spec in _specs) {
      spec.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.existing == null ? '添加菜品' : '编辑菜品',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            maxLength: 40,
            autofocus: true,
            decoration: const InputDecoration(labelText: '菜品名称'),
          ),
          const SizedBox(height: 10),
          Semantics(
            button: true,
            label:
                _imageBytes != null ||
                    (!_removeImage &&
                        (widget.existing?.imageUrl.isNotEmpty ?? false))
                ? '更换菜品图片'
                : '选择菜品图片',
            child: InkWell(
              onTap: _saving ? null : _chooseImage,
              borderRadius: BorderRadius.circular(18),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: _imageBytes != null
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : !_removeImage &&
                            (widget.existing?.imageUrl.isNotEmpty ?? false)
                      ? Image.network(
                          widget.existing!.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _ImagePlaceholder(),
                        )
                      : const _ImagePlaceholder(),
                ),
              ),
            ),
          ),
          if (_imageBytes != null ||
              (!_removeImage &&
                  (widget.existing?.imageUrl.isNotEmpty ?? false)))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _imageBytes = null;
                        _imageName = '';
                        _removeImage = true;
                      }),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('移除图片'),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _category,
            maxLength: 20,
            decoration: const InputDecoration(labelText: '分类'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '价格',
              prefixText: '¥ ',
            ),
          ),
          const SizedBox(height: 12),
          Text('喜欢程度：${_rating.round()} 分'),
          Slider(
            value: _rating,
            min: 1,
            max: 5,
            divisions: 4,
            label: '${_rating.round()}',
            onChanged: (value) => setState(() => _rating = value),
          ),
          TextField(
            controller: _description,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: '说明（可选）'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: 500,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '口味与偏好（可选）'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _location,
            maxLength: 100,
            decoration: const InputDecoration(labelText: '餐厅或位置（可选）'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: '标签',
              hintText: '清淡 快手 周末',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('当前可点'),
            subtitle: const Text('关闭后仍保留菜品，但不能加入订单'),
            value: _available,
            onChanged: _saving
                ? null
                : (value) => setState(() => _available = value),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '规格定制',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _saving ? null : _addSpecGroup,
                icon: const Icon(Icons.add_rounded),
                label: const Text('添加规格组'),
              ),
            ],
          ),
          ..._specs.asMap().entries.map(
            (entry) => _SpecEditor(
              draft: entry.value,
              onDelete: () => _removeSpecGroup(entry.key),
              enabled: !_saving,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? '正在保存…'
                  : widget.existing == null
                  ? '加入菜单'
                  : '保存修改',
            ),
          ),
        ],
      ),
    ),
  );
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 34),
          SizedBox(height: 6),
          Text('选择一张菜品图片'),
        ],
      ),
    ),
  );
}

class _SpecDraft {
  _SpecDraft(this.name, this.options);
  factory _SpecDraft.empty() =>
      _SpecDraft(TextEditingController(), [_SpecOptionDraft.empty()]);
  factory _SpecDraft.fromModel(DishSpecGroup group) => _SpecDraft(
    TextEditingController(text: group.name),
    group.options.map(_SpecOptionDraft.fromModel).toList(),
  );

  final TextEditingController name;
  final List<_SpecOptionDraft> options;

  DishSpecGroup toModel() => DishSpecGroup(
    name: name.text.trim(),
    options: options
        .map((option) => option.toModel())
        .where((option) => option.name.isNotEmpty)
        .take(20)
        .toList(),
  );

  void dispose() {
    name.dispose();
    for (final option in options) {
      option.dispose();
    }
  }
}

class _SpecOptionDraft {
  _SpecOptionDraft(this.name, this.price);
  factory _SpecOptionDraft.empty() =>
      _SpecOptionDraft(TextEditingController(), TextEditingController());
  factory _SpecOptionDraft.fromModel(DishSpecOption option) => _SpecOptionDraft(
    TextEditingController(text: option.name),
    TextEditingController(
      text: option.priceAdd == 0 ? '' : option.priceAdd.toString(),
    ),
  );

  final TextEditingController name;
  final TextEditingController price;
  DishSpecOption toModel() => DishSpecOption(
    name: name.text.trim(),
    priceAdd: double.tryParse(price.text) ?? 0,
  );
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _SpecEditor extends StatefulWidget {
  const _SpecEditor({
    required this.draft,
    required this.onDelete,
    required this.enabled,
  });
  final _SpecDraft draft;
  final VoidCallback onDelete;
  final bool enabled;

  @override
  State<_SpecEditor> createState() => _SpecEditorState();
}

class _SpecEditorState extends State<_SpecEditor> {
  void _addOption() =>
      setState(() => widget.draft.options.add(_SpecOptionDraft.empty()));

  void _removeOption(int index) {
    setState(() => widget.draft.options.removeAt(index).dispose());
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.draft.name,
                  enabled: widget.enabled,
                  maxLength: 20,
                  decoration: const InputDecoration(
                    labelText: '规格组名称',
                    hintText: '例如：甜度',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '删除规格组',
                onPressed: widget.enabled ? widget.onDelete : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          ...widget.draft.options.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: entry.value.name,
                      enabled: widget.enabled,
                      maxLength: 20,
                      decoration: const InputDecoration(labelText: '选项名'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 112,
                    child: TextField(
                      controller: entry.value.price,
                      enabled: widget.enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '加价',
                        prefixText: '¥ ',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '删除规格选项',
                    onPressed: widget.enabled
                        ? () => _removeOption(entry.key)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.enabled ? _addOption : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加选项'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CategoryManager extends StatefulWidget {
  const _CategoryManager({required this.repository});
  final TogetherRepository repository;
  @override
  State<_CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<_CategoryManager> {
  final _name = TextEditingController();
  late Future<List<MenuCategory>> _items = widget.repository.categories();
  bool _busy = false;

  void _reload() => setState(() => _items = widget.repository.categories());

  Future<void> _add() async {
    if (_name.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.addCategory(_name.text);
      _name.clear();
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(MenuCategory item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.repository.deleteCategory(item.id);
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('菜单分类', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  maxLength: 20,
                  decoration: const InputDecoration(labelText: '新分类名称'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: '添加分类',
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<MenuCategory>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? const [];
                if (items.isEmpty) return const Center(child: Text('还没有自定义分类'));
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return ListTile(
                      minTileHeight: 54,
                      leading: const Icon(Icons.label_outline_rounded),
                      title: Text(item.name),
                      trailing: IconButton(
                        tooltip: '删除${item.name}',
                        onPressed: _busy ? null : () => _delete(item),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
