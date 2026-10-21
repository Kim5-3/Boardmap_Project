import 'package:flutter/material.dart';
import '../models/boarding_house.dart';
import 'login_screen.dart';

const _green = Color(0xFF078747);
const _deepGreen = Color(0xFF003D2D);
const _page = Color(0xFFF4F7F4);
const _ink = Color(0xFF142D27);

class RenterHomeScreen extends StatefulWidget {
  const RenterHomeScreen({super.key});

  @override
  State<RenterHomeScreen> createState() => _RenterHomeScreenState();
}

class _RenterHomeScreenState extends State<RenterHomeScreen> {
  int _nav = 0;
  final _search = TextEditingController();
  final _minPrice = TextEditingController(text: '1000');
  final _maxPrice = TextEditingController(text: '5000');
  String _roomType = 'Any room';
  String _distance = 'Within 5 km';
  String _location = 'Cabadbaran City';
  DateTime? _moveIn;
  final Set<String> _amenities = {};
  final Set<String> _saved = {};

  final List<BoardingHouse> _houses = const [
    BoardingHouse(name: 'Maple Boarding House', location: 'Poblacion, Cabadbaran City',
      price: 2500, availableRooms: 12, roomType: 'Solo', match: 95, rating: 4.8,
      amenities: ['Wi-Fi', 'CR', 'Laundry'], imageColor: 0xFFDDE8D7),
    BoardingHouse(name: 'Riverside Boarding House', location: 'Mabini St., Cabadbaran City',
      price: 2000, availableRooms: 8, roomType: 'Shared', match: 92, rating: 4.6,
      amenities: ['Wi-Fi', 'Aircon', 'Kitchen'], imageColor: 0xFFD8E9DE),
    BoardingHouse(name: 'City View Boarding House', location: 'Near CSU, Cabadbaran City',
      price: 2800, availableRooms: 4, roomType: 'Solo', match: 89, rating: 4.7,
      amenities: ['Wi-Fi', 'CR', 'Aircon'], imageColor: 0xFFE9E3D6),
  ];

  @override
  void dispose() {
    _search.dispose();
    _minPrice.dispose();
    _maxPrice.dispose();
    super.dispose();
  }

  List<BoardingHouse> get _filtered {
    final q = _search.text.trim().toLowerCase();
    final min = int.tryParse(_minPrice.text) ?? 0;
    final max = int.tryParse(_maxPrice.text) ?? 999999;
    return _houses.where((h) {
      final textMatch = q.isEmpty || '${h.name} ${h.location}'.toLowerCase().contains(q);
      final priceMatch = h.price >= min && h.price <= max;
      final typeMatch = _roomType == 'Any room' || h.roomType == _roomType;
      final amenityMatch = _amenities.every((a) => h.amenities.contains(a));
      return textMatch && priceMatch && typeMatch && amenityMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: LayoutBuilder(builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        return Row(children: [
          if (desktop) BoardMapSidebar(active: _nav, owner: false, onTap: _navigate),
          Expanded(child: Column(children: [
            BoardMapTopBar(
                          search: _search,
                          hint: 'Search for boarding houses...',
                          onSearch: () => setState(() {}),
                          onProfile: () => _navigate(5),
                          onLogout: _logout,
                        ),
                          Expanded(child: _nav == 1
              ? _simplePage('Explore Cabadbaran City', Icons.map_outlined,
                  'Map pins will appear here when you connect the GIS/map service.')
              : _nav == 2
                ? _simplePage('Recommendations', Icons.auto_awesome_outlined,
                    'Your best matches are based on your budget, room type, distance, and selected amenities.')
                : _nav == 3
                  ? _savedPage()
                  : _nav == 5
                    ? _simplePage('Your Profile', Icons.person_outline,
                        'Manage your renter details and preferences here.')
                    : _homeContent(desktop)),
          ])),
        ]);
      }),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 980
        ? NavigationBar(
            selectedIndex: _nav > 4 ? 0 : _nav,
            onDestinationSelected: _navigate,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
              NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Match'),
              NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Saved'),
              NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          )
        : null,
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of BoardMap?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _navigate(int index) => setState(() => _nav = index == 4 ? 5 : index);

  Widget _homeContent(bool desktop) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(desktop ? 24 : 14),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _RenterHero(compact: !desktop),
          const SizedBox(height: 18),
          _smartSearch(),
          const SizedBox(height: 22),
          Row(children: [
            const Icon(Icons.star_outline_rounded, color: _deepGreen, size: 27),
            const SizedBox(width: 8),
            const Expanded(child: Text('Best matches for you',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink))),
            TextButton(onPressed: () => setState(() => _nav = 2),
              child: const Text('View all  →')),
          ]),
          const SizedBox(height: 10),
          if (_filtered.isEmpty)
            const _EmptyState(text: 'No sample listings match these filters. Try a wider budget or remove an amenity.')
          else
            LayoutBuilder(builder: (context, c) {
              final columns = c.maxWidth >= 1100 ? 3 : c.maxWidth >= 650 ? 2 : 1;
              return Wrap(spacing: 16, runSpacing: 16, children: _filtered.map((h) =>
                SizedBox(width: (c.maxWidth - (columns - 1) * 16) / columns,
                  child: _HouseCard(house: h, saved: _saved.contains(h.name),
                    onSave: () => setState(() {
                      if (!_saved.add(h.name)) _saved.remove(h.name);
                    }),
                    onView: () => _showHouse(h),
                  ))).toList());
            }),
          const SizedBox(height: 22),
          _MapPreview(onTap: () => setState(() => _nav = 1)),
          const SizedBox(height: 18),
          Text('BoardMap helps you compare places before visiting.',
            style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13)),
        ]),
      )),
    );
  }

  Widget _smartSearch() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0EAE3)),
        boxShadow: [BoxShadow(color: _deepGreen.withValues(alpha: .05), blurRadius: 18, offset: const Offset(0, 7))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
            color: _green, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.manage_search_rounded, color: Colors.white)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Smart Search', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
            Text('Tell us what matters and find your best match.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ])),
          TextButton(onPressed: _resetFilters, child: const Text('Reset')),
        ]),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final two = c.maxWidth < 700;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            _filterBox(width: two ? c.maxWidth : (c.maxWidth - 24) / 3, label: 'LOCATION',
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                isExpanded: true, value: _location, items: const [
                  DropdownMenuItem(value: 'Cabadbaran City', child: Text('Cabadbaran City')),
                  DropdownMenuItem(value: 'Near CSU', child: Text('Near CSU')),
                  DropdownMenuItem(value: 'Poblacion', child: Text('Poblacion')),
                ], onChanged: (v) => setState(() => _location = v ?? _location)))),
            _filterBox(width: two ? c.maxWidth : (c.maxWidth - 24) / 3, label: 'MONTHLY BUDGET (₱)',
              child: Row(children: [
                Expanded(child: TextField(controller: _minPrice, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Min'))),
                const Text('—', style: TextStyle(color: Colors.blueGrey)),
                Expanded(child: TextField(controller: _maxPrice, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Max'))),
              ])),
            _filterBox(width: two ? c.maxWidth : (c.maxWidth - 24) / 3, label: 'ROOM TYPE',
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                isExpanded: true, value: _roomType, items: const [
                  DropdownMenuItem(value: 'Any room', child: Text('Any room')),
                  DropdownMenuItem(value: 'Solo', child: Text('Solo room')),
                  DropdownMenuItem(value: 'Shared', child: Text('Shared room')),
                ], onChanged: (v) => setState(() => _roomType = v ?? _roomType)))),
            _filterBox(width: two ? c.maxWidth : (c.maxWidth - 24) / 3, label: 'MOVE-IN DATE',
              child: InkWell(onTap: () async {
                final picked = await showDatePicker(context: context,
                  initialDate: DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                if (picked != null) setState(() => _moveIn = picked);
              }, child: Row(children: [
                const Icon(Icons.calendar_month_outlined, size: 18, color: _green),
                const SizedBox(width: 8),
                Expanded(child: Text(_moveIn == null ? 'Select date' : '${_moveIn!.month}/${_moveIn!.day}/${_moveIn!.year}')),
                const Icon(Icons.keyboard_arrow_down),
              ]))),
            _filterBox(width: two ? c.maxWidth : (c.maxWidth - 24) / 3, label: 'DISTANCE',
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                isExpanded: true, value: _distance, items: const [
                  DropdownMenuItem(value: 'Within 1 km', child: Text('Within 1 km')),
                  DropdownMenuItem(value: 'Within 3 km', child: Text('Within 3 km')),
                  DropdownMenuItem(value: 'Within 5 km', child: Text('Within 5 km')),
                  DropdownMenuItem(value: 'Any distance', child: Text('Any distance')),
                ], onChanged: (v) => setState(() => _distance = v ?? _distance)))),
            _filterBox(width: two ? c.maxWidth : (c.maxWidth - 24) / 3, label: 'AMENITIES',
              child: Wrap(spacing: 3, runSpacing: 0, children: ['Wi-Fi','CR','Aircon','Laundry','Kitchen'].map((a) =>
                FilterChip(label: Text(a, style: const TextStyle(fontSize: 11)),
                  selected: _amenities.contains(a), onSelected: (v) => setState(() {
                    v ? _amenities.add(a) : _amenities.remove(a);
                  }), visualDensity: VisualDensity.compact, showCheckmark: false,
                  selectedColor: const Color(0xFFD8F3E3))).toList())),
          ]);
        }),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 48, child: FilledButton.icon(
          onPressed: () => setState(() {}),
          icon: const Icon(Icons.search_rounded), label: const Text('Find My Match'),
          style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ]),
    );
  }

  Widget _filterBox({required double width, required String label, required Widget child}) =>
    SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, letterSpacing: .7, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 6),
      Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: const Color(0xFFF8FBF8), border: Border.all(color: const Color(0xFFDCE6DE)),
          borderRadius: BorderRadius.circular(10)), child: child),
    ]));

  void _resetFilters() => setState(() {
    _search.clear(); _minPrice.text = '1000'; _maxPrice.text = '5000';
    _roomType = 'Any room'; _distance = 'Within 5 km'; _location = 'Cabadbaran City';
    _amenities.clear(); _moveIn = null;
  });

  Widget _savedPage() => SingleChildScrollView(padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Saved boarding houses', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      ..._houses.where((h) => _saved.contains(h.name)).map((h) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _HouseCard(house: h, saved: true, onSave: () => setState(() => _saved.remove(h.name)),
          onView: () => _showHouse(h)))),
      if (_saved.isEmpty) const _EmptyState(text: 'Tap the heart on a listing to save it here.'),
    ]));

  Widget _simplePage(String title, IconData icon, String subtitle) => Center(
    child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 56, color: _green), const SizedBox(height: 12),
      Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
      const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.blueGrey)),
      const SizedBox(height: 16), const Text('Demo UI — connect the API / map provider to load live data.', textAlign: TextAlign.center),
    ])));

  void _showHouse(BoardingHouse h) => showDialog<void>(context: context, builder: (ctx) => AlertDialog(
    icon: const Icon(Icons.home_work_rounded, color: _green, size: 38),
    title: Text(h.name), content: Text('${h.location}\n\n₱${h.price}/month\n${h.availableRooms} rooms available\nRating ${h.rating}\nAmenities: ${h.amenities.join(', ')}'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      FilledButton(onPressed: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inquiry UI demo: connect this button to your backend to contact the owner.'))); },
        child: const Text('Send inquiry')),
    ]));

}

class BoardMapSidebar extends StatelessWidget {
  const BoardMapSidebar({required this.active, required this.owner, required this.onTap});
  final int active; final bool owner; final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final items = owner
      ? const [(Icons.dashboard_outlined,'Dashboard'),(Icons.home_work_outlined,'My Listings'),(Icons.insights_outlined,'Insights'),(Icons.bar_chart_outlined,'Analytics'),(Icons.person_outline,'Profile'),(Icons.settings_outlined,'Settings')]
      : const [(Icons.home_outlined,'Home'),(Icons.map_outlined,'Map'),(Icons.auto_awesome_outlined,'Recommendations'),(Icons.favorite_border,'Saved'),(Icons.person_outline,'Profile')];
    return Container(width: 220, decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,colors:[_deepGreen,Color(0xFF075B42),Color(0xFF003427)])),
      child: Column(children: [
        const SizedBox(height: 20),
        Container(width: 76,height: 76, decoration: BoxDecoration(color: Colors.white.withValues(alpha:.10),borderRadius: BorderRadius.circular(22)),
          child: const Icon(Icons.other_houses_rounded,color: Colors.white,size: 48)),
        const SizedBox(height: 6),
        const Text('CBR',style: TextStyle(color: Colors.white,fontSize: 25,fontWeight: FontWeight.w900,height:1)),
        const Text('BoardMap',style: TextStyle(color: Colors.white,fontSize: 13)),
        const SizedBox(height: 35),
        ...List.generate(items.length,(i) {
          final index = owner ? i : (i == 4 ? 5 : i);
          final selected = active == index;
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 10,vertical: 3),
            child: InkWell(borderRadius: BorderRadius.circular(12),onTap:()=>onTap(index),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12,vertical: 13),
                decoration: BoxDecoration(color:selected?const Color(0xFF169D55):Colors.transparent,borderRadius:BorderRadius.circular(12)),
                child: Row(children:[Icon(items[i].$1,color:Colors.white,size:20),const SizedBox(width:12),
                  Expanded(child:Text(items[i].$2,style:TextStyle(color:Colors.white,fontWeight:selected?FontWeight.w800:FontWeight.w500,fontSize:13)))])
              )));
        }),
        const Spacer(),
        const Padding(padding: EdgeInsets.all(16), child: Text('CABADBARAN CITY\nAgusan del Norte',textAlign:TextAlign.center,
          style:TextStyle(color:Colors.white70,fontSize:11,height:1.5))),
      ]),
    );
  }
}

class BoardMapTopBar extends StatelessWidget {
  const BoardMapTopBar({required this.search, required this.hint, required this.onSearch, required this.onProfile, required this.onLogout});
  final TextEditingController search; final String hint; final VoidCallback onSearch,onProfile,onLogout;
  @override
  Widget build(BuildContext context) => Container(height: 66,padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(color: Colors.white,border: Border(bottom: BorderSide(color: Color(0xFFE8EEE9)))),
    child: Row(children: [
      Expanded(child: Container(height: 42,padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: const Color(0xFFF4F6F5),borderRadius: BorderRadius.circular(24)),
        child: Row(children:[const Icon(Icons.search,color:Colors.blueGrey,size:20),const SizedBox(width:8),
          Expanded(child:TextField(controller:search,onSubmitted:(_)=>onSearch(),decoration:InputDecoration(hintText:hint,border:InputBorder.none,isDense:true))),
          IconButton(onPressed:onSearch,icon:const Icon(Icons.arrow_forward_rounded,size:18))]))),
      const SizedBox(width:12),
      IconButton(
        tooltip: 'Report an issue',
        onPressed: () => Navigator.pushNamed(context, '/report'),
        icon: const Icon(Icons.flag_outlined),
      ),
      IconButton(onPressed:()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('No new notifications in this demo.'))),
        icon:const Icon(Icons.notifications_none_rounded)),
      const SizedBox(width:4),
      InkWell(onTap:onProfile,borderRadius:BorderRadius.circular(30),child:const CircleAvatar(backgroundColor:_deepGreen,child:Text('KL',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800)))),
      const SizedBox(width:4),
      IconButton(tooltip: 'Log out', onPressed: onLogout, icon: const Icon(Icons.logout_rounded)),
    ]) );
}

class _RenterHero extends StatelessWidget {
  const _RenterHero({required this.compact}); final bool compact;
  @override
  Widget build(BuildContext context) => Container(width:double.infinity,padding:EdgeInsets.all(compact?20:28),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),gradient:const LinearGradient(
      begin:Alignment.centerLeft,end:Alignment.centerRight,colors:[Color(0xFFE5F4E9),Color(0xFFD8E9F3),Color(0xFFF0F3E9)])),
    child:Stack(children:[
      Positioned(right:0,top:0,bottom:0,child:Icon(Icons.location_city_rounded,size:compact?90:150,color:_green.withValues(alpha:.13))),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.8),borderRadius:BorderRadius.circular(20)),
          child:const Text('YOUR NEXT PLACE STARTS HERE',style:TextStyle(fontSize:10,letterSpacing:1,fontWeight:FontWeight.w800,color:_deepGreen))),
        const SizedBox(height:12),
        Text('Find a place\\nthat fits your life',style:TextStyle(fontSize:compact?28:36,height:1.05,fontWeight:FontWeight.w900,letterSpacing:-.8,color:_deepGreen)),
        const SizedBox(height:8),
        const Text('Discover boarding houses in Cabadbaran City.',style:TextStyle(fontSize:13,color:_ink)),
      ]),
    ]));
}

class _HouseCard extends StatelessWidget {
  const _HouseCard({required this.house,required this.saved,required this.onSave,required this.onView});
  final BoardingHouse house; final bool saved; final VoidCallback onSave,onView;
  @override
  Widget build(BuildContext context) => Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17),
    border:Border.all(color:const Color(0xFFE1EAE3)),boxShadow:[BoxShadow(color:_deepGreen.withValues(alpha:.04),blurRadius:12,offset:const Offset(0,4))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Stack(children:[
        Container(height:145,width:double.infinity,decoration:BoxDecoration(
          color:Color(house.imageColor),borderRadius:const BorderRadius.vertical(top:Radius.circular(17))),
          child:Center(child:Icon(Icons.house_rounded,size:82,color:_deepGreen.withValues(alpha:.35)))),
        Positioned(left:12,top:12,child:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
          decoration:BoxDecoration(color:_green,borderRadius:BorderRadius.circular(20)),child:Text('${house.match}% match',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:11)))),
        Positioned(right:10,top:8,child:IconButton(onPressed:onSave,style:IconButton.styleFrom(backgroundColor:Colors.white),icon:Icon(saved?Icons.favorite:Icons.favorite_border,color:saved?Colors.red:_green))),
      ]),
      Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(house.name,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:_ink)),
        const SizedBox(height:6),
        Text('₱${house.price.toString()}/month',style:const TextStyle(color:_green,fontWeight:FontWeight.w900,fontSize:19)),
        const SizedBox(height:5),
        Row(children:[const Icon(Icons.location_on_outlined,size:15,color:_green),const SizedBox(width:4),
          Expanded(child:Text(house.location,style:const TextStyle(fontSize:11,color:Colors.blueGrey),maxLines:1,overflow:TextOverflow.ellipsis))]),
        const SizedBox(height:5),
        Row(children:[const Icon(Icons.bed_outlined,size:15,color:Colors.blueGrey),const SizedBox(width:5),
          Text('${house.availableRooms} rooms available',style:const TextStyle(fontSize:11,color:Colors.blueGrey)),
          const Spacer(),const Icon(Icons.star_rounded,color:Color(0xFFF4B400),size:16),Text(' ${house.rating}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))]),
        const SizedBox(height:10),
        Wrap(spacing:5,runSpacing:5,children:house.amenities.map((a)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
          decoration:BoxDecoration(color:const Color(0xFFF0F7F1),borderRadius:BorderRadius.circular(7)),child:Text(a,style:const TextStyle(fontSize:10,color:_deepGreen,fontWeight:FontWeight.w600)))).toList()),
        const SizedBox(height:12),
        SizedBox(width:double.infinity,child:OutlinedButton(onPressed:onView,style:OutlinedButton.styleFrom(foregroundColor:_deepGreen,side:const BorderSide(color:_green),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),child:const Text('View details'))),
      ]))
    ]));
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.onTap}); final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(
    color:const Color(0xFFE4F0E9),borderRadius:BorderRadius.circular(18),border:Border.all(color:const Color(0xFFD3E3D8))),
    child:Row(children:[
      const Icon(Icons.map_outlined,size:40,color:_green),const SizedBox(width:14),
      const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Explore on the map',style:TextStyle(fontWeight:FontWeight.w800,fontSize:16,color:_deepGreen)),
        SizedBox(height:4),Text('See nearby boarding houses and compare their locations.',style:TextStyle(fontSize:12,color:_ink)),
      ])),
      FilledButton(onPressed:onTap,style:FilledButton.styleFrom(backgroundColor:_deepGreen),child:const Text('View map')),
    ]));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text}); final String text;
  @override
  Widget build(BuildContext context) => Container(width:double.infinity,padding:const EdgeInsets.all(28),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16)),child:Column(children:[
      const Icon(Icons.search_off_rounded,size:42,color:_green),const SizedBox(height:8),
      Text(text,textAlign:TextAlign.center,style:const TextStyle(color:Colors.blueGrey)),
    ]));
}
