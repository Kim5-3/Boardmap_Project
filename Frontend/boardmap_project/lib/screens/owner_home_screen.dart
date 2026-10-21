import 'package:flutter/material.dart';
import 'renter_home_screen.dart' show BoardMapSidebar;

const _green = Color(0xFF078747);
const _deepGreen = Color(0xFF003D2D);
const _page = Color(0xFFF4F7F4);
const _ink = Color(0xFF142D27);

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});
  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _nav = 0;
  final List<_OwnerListing> _listings = [
    _OwnerListing('Maple Boarding House', 'Poblacion, Cabadbaran City', 2500, 6, 'Active'),
    _OwnerListing('Riverside Boarding House', 'Mabini St., Cabadbaran City', 2000, 8, 'Active'),
    _OwnerListing('City View Boarding House', 'Near CSU, Cabadbaran City', 2800, 4, 'Pending'),
  ];
  final List<_Inquiry> _inquiries = [
    _Inquiry('Maria Santos', 'Interested in Maple Boarding House', '2h ago'),
    _Inquiry('John Dela Cruz', 'Asking about room availability', '3h ago'),
    _Inquiry('Ana Reyes', 'Asking for a solo room', '5h ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      body: LayoutBuilder(builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 980;
        return Row(children: [
          if (desktop) BoardMapSidebar(active: _nav, owner: true, onTap: (v) => setState(() => _nav = v)),
          Expanded(child: Column(children: [
            
            Expanded(child: _nav == 1 ? _listingsPage()
              : _nav == 2 ? _simple('Insights', Icons.insights_outlined, 'Understand listing performance and renter interest.')
              : _nav == 3 ? _simple('Analytics', Icons.bar_chart_rounded, 'Charts and occupancy trends will use your real listing data.')
              : _nav == 4 ? _simple('Owner Profile', Icons.person_outline, 'Update your owner information and contact details.')
              : _nav == 5 ? _simple('Settings', Icons.settings_outlined, 'Manage notifications, account preferences, and privacy.')
              : _dashboard(desktop)),
          ])),
        ]);
      }),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 980
        ? NavigationBar(selectedIndex: _nav.clamp(0, 5).toInt(), onDestinationSelected: (v) => setState(() => _nav = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.home_work_outlined), label: 'Listings'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Insights'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Analytics'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          ])
        : null,
    );
  }

  Widget _dashboard(bool desktop) => SingleChildScrollView(
    padding: EdgeInsets.all(desktop ? 24 : 14),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1500),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _OwnerHero(compact: !desktop),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/report'),
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Report an issue'),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final stats = [
            _StatCard(icon: Icons.home_work_outlined, label: 'Total Listings', value: '${_listings.length}', trend: 'Your properties'),
            _StatCard(icon: Icons.bed_outlined, label: 'Available Rooms', value: '${_listings.fold<int>(0, (total, listing) => total + listing.rooms)}', trend: 'Across listings'),
            _StatCard(icon: Icons.mail_outline_rounded, label: 'Pending Inquiries', value: '${_inquiries.length}', trend: 'Needs attention'),
            const _StatCard(icon: Icons.visibility_outlined, label: 'Profile Views', value: '1.2K', trend: 'Demo statistics'),
          ];
          return Wrap(spacing: 12, runSpacing: 12, children: stats.map((s) =>
            SizedBox(width: wide ? (c.maxWidth - 36) / 4 : (c.maxWidth - 12) / 2, child: s)).toList());
        }),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 1000;
          return Flex(direction: wide ? Axis.horizontal : Axis.vertical, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExpandedIfWide(wide: wide, child: _listingTable()),
              SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
              ExpandedIfWide(wide: wide, child: _addChecklist()),
            ]);
        }),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 750;
          return Flex(direction: wide ? Axis.horizontal : Axis.vertical, crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExpandedIfWide(wide: wide, child: _occupancy()),
            SizedBox(width: wide ? 16 : 0, height: wide ? 0 : 16),
            ExpandedIfWide(wide: wide, child: _recentInquiries()),
          ]);
        }),
      ]))),
  );

  Widget _listingTable() => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Text('Your Listings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink))),
      TextButton(onPressed: () => setState(() => _nav = 1), child: const Text('View all  →'))]),
    const SizedBox(height: 8),
    ..._listings.map((l) => Container(padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEDF1ED)))),
      child: Row(children: [
        Container(width: 46,height: 44,decoration: BoxDecoration(color: const Color(0xFFDDECE0),borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.house_rounded,color:_deepGreen)),
        const SizedBox(width: 10),
        Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _ink)),
          Text(l.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
        ])),
        const SizedBox(width: 6),
        Expanded(flex: 2, child: Text('₱${l.price}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
        if (MediaQuery.sizeOf(context).width > 700) Text('${l.rooms} rooms', style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8,vertical: 5),
          decoration: BoxDecoration(color: l.status == 'Active' ? const Color(0xFFDDF5E5) : const Color(0xFFFFEACB),borderRadius: BorderRadius.circular(20)),
          child: Text(l.status,style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:l.status=='Active'?_green:const Color(0xFF9A5B00)))),
        PopupMenuButton<String>(onSelected: (v) => v == 'edit' ? _editListing(l) : _confirmDelete(l),
          itemBuilder: (_) => const [PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'delete',child:Text('Delete'))],
          child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.more_vert,size:20))),
      ]))),
    const SizedBox(height: 8),
    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _addListing,
      icon: const Icon(Icons.add), label: const Text('Add boarding house'),
      style: OutlinedButton.styleFrom(foregroundColor: _deepGreen, side: const BorderSide(color: _green)))),
  ]));

  Widget _addChecklist() => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Add a boarding house', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
    const SizedBox(height: 14),
    ...['Property details','Room types & pricing','Amenities & facilities','Location pin on map','Rules & requirements','Photos & contact details'].map((s) =>
      Padding(padding: const EdgeInsets.only(bottom: 13), child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: _green, size: 19), const SizedBox(width: 9),
        Expanded(child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      ]))),
    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _addListing,
      icon: const Icon(Icons.add), label: const Text('Create listing'),
      style: FilledButton.styleFrom(backgroundColor: _deepGreen))),
  ]));

  Widget _occupancy() => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Occupancy Overview', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
    const SizedBox(height: 16),
    Row(children: [
      SizedBox(width: 105,height:105,child:Stack(alignment:Alignment.center,children:[
        SizedBox.expand(child:CircularProgressIndicator(value:.72,strokeWidth:12,backgroundColor:const Color(0xFFE8E5F1),color:_green)),
        const Column(mainAxisSize:MainAxisSize.min,children:[Text('72%',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900,color:_deepGreen)),Text('Occupied',style:TextStyle(fontSize:10))]),
      ])),
      const SizedBox(width: 18),
      const Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _Legend(color:_green,text:'Occupied (13)'),SizedBox(height:10),_Legend(color:Color(0xFFE8E5F1),text:'Available (5)'),
      ])),
    ]),
  ]));

  Widget _recentInquiries() => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children:[const Expanded(child:Text('Recent Renter Inquiries',style:TextStyle(fontSize:17,fontWeight:FontWeight.w800,color:_ink))),
      TextButton(onPressed:()=>_showInquiries(),child:const Text('View all →'))]),
    ..._inquiries.take(3).map((i) => Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Row(children:[
      CircleAvatar(backgroundColor:const Color(0xFFDDF0E5),child:Text(i.name.isNotEmpty?i.name[0]:'?',style:const TextStyle(color:_deepGreen,fontWeight:FontWeight.w800))),
      const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(i.name,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),
        Text(i.message,style:const TextStyle(fontSize:10,color:Colors.blueGrey),maxLines:1,overflow:TextOverflow.ellipsis),
      ])),Text(i.time,style:const TextStyle(fontSize:10,color:Colors.blueGrey)),
    ]))),
  ]));

  Widget _listingsPage() => SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[const Expanded(child:Text('My Listings',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:_ink))),
      FilledButton.icon(onPressed:_addListing,icon:const Icon(Icons.add),label:const Text('Add property'),style:FilledButton.styleFrom(backgroundColor:_green))]),
    const SizedBox(height:16),_listingTable(),
  ]));

  Widget _simple(String title, IconData icon, String description) => Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Icon(icon,size:58,color:_green),const SizedBox(height:12),Text(title,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900,color:_ink)),
    const SizedBox(height:8),Text(description,textAlign:TextAlign.center,style:const TextStyle(color:Colors.blueGrey)),
    const SizedBox(height:12),const Text('Demo UI — connect your API/database for live owner data.',textAlign:TextAlign.center),
  ])));

  Widget _panel({required Widget child}) => Container(width:double.infinity,padding:const EdgeInsets.all(17),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(17),border:Border.all(color:const Color(0xFFE0E9E2)),
      boxShadow:[BoxShadow(color:_deepGreen.withValues(alpha:.035),blurRadius:12,offset:const Offset(0,4))]),child:child);

  Future<void> _addListing() async {
    final name = TextEditingController(); final price = TextEditingController(); final rooms = TextEditingController();
    final result = await showDialog<_OwnerListing>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Add boarding house'),
      content:SizedBox(width:420,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Property name *',border:OutlineInputBorder())),
        const SizedBox(height:10),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Monthly price (₱) *',border:OutlineInputBorder())),
        const SizedBox(height:10),TextField(controller:rooms,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Available rooms *',border:OutlineInputBorder())),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:(){
          final n=name.text.trim(); final p=int.tryParse(price.text); final r=int.tryParse(rooms.text);
          if(n.isEmpty||p==null||r==null||p<=0||r<0){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('Enter a name, valid price, and room count.')));return;}
          Navigator.pop(ctx,_OwnerListing(n,'Cabadbaran City',p,r,'Pending'));
        },child:const Text('Save listing'))],
    ));
    name.dispose();price.dispose();rooms.dispose();
    if(result!=null && mounted) setState(()=>_listings.add(result));
  }

  Future<void> _editListing(_OwnerListing l) async {
    final name=TextEditingController(text:l.name); final price=TextEditingController(text:'${l.price}'); final rooms=TextEditingController(text:'${l.rooms}');
    final result=await showDialog<_OwnerListing>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Edit listing'),
      content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:name,decoration:const InputDecoration(labelText:'Property name',border:OutlineInputBorder())),
        const SizedBox(height:10),TextField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Monthly price',border:OutlineInputBorder())),
        const SizedBox(height:10),TextField(controller:rooms,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Available rooms',border:OutlineInputBorder())),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:(){
        final p=int.tryParse(price.text);final r=int.tryParse(rooms.text);
        if(name.text.trim().isEmpty||p==null||r==null||p<=0||r<0){
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('Enter a name, valid price, and room count.')));
          return;
        }
        Navigator.pop(ctx,_OwnerListing(name.text.trim(),l.location,p,r,l.status));
      },child:const Text('Save'))]));
    name.dispose();price.dispose();rooms.dispose();
    if(result!=null&&mounted)setState(()=>_listings[_listings.indexOf(l)]=result);
  }

  void _confirmDelete(_OwnerListing l) => showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete listing?'),
    content:Text('Remove "${l.name}" from this demo dashboard?'),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
      FilledButton(onPressed:(){setState(()=>_listings.remove(l));Navigator.pop(ctx);},style:FilledButton.styleFrom(backgroundColor:Colors.red),child:const Text('Delete')),
    ]));

  void _showInquiries() => showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Renter inquiries'),
    content:SizedBox(width:400,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:_inquiries.map((i)=>ListTile(
      leading:const CircleAvatar(child:Icon(Icons.person_outline)),title:Text(i.name),subtitle:Text(i.message),trailing:Text(i.time))).toList()))),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]));
}

class _OwnerListing {
  _OwnerListing(this.name,this.location,this.price,this.rooms,this.status);
  final String name,location,status; final int price,rooms;
}
class _Inquiry { const _Inquiry(this.name,this.message,this.time); final String name,message,time; }

class _OwnerHero extends StatelessWidget {
  const _OwnerHero({required this.compact});final bool compact;
  @override
  Widget build(BuildContext context)=>Container(width:double.infinity,padding:EdgeInsets.all(compact?20:28),
    decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),gradient:const LinearGradient(
      begin:Alignment.centerLeft,end:Alignment.centerRight,colors:[Color(0xFFE3F3E8),Color(0xFFE4EAF0),Color(0xFFF0F4E9)])),
    child:Stack(children:[Positioned(right:0,top:0,bottom:0,child:Icon(Icons.cottage_rounded,size:compact?95:155,color:_green.withValues(alpha:.15))),
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('OWNER DASHBOARD',style:TextStyle(fontSize:10,letterSpacing:1.1,fontWeight:FontWeight.w900,color:_green)),
        const SizedBox(height:10),Text('Manage your\\nboarding houses',style:TextStyle(fontSize:compact?27:34,height:1.05,fontWeight:FontWeight.w900,letterSpacing:-.7,color:_deepGreen)),
        const SizedBox(height:8),const Text('Grow your rental business with CBR BoardMap.',style:TextStyle(fontSize:13,color:_ink)),
      ])]));
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon,required this.label,required this.value,required this.trend});
  final IconData icon;final String label,value,trend;
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(15),
    border:Border.all(color:const Color(0xFFE0E9E2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:_green,size:24),const SizedBox(height:10),Text(label,style:const TextStyle(fontSize:11,color:Colors.blueGrey,fontWeight:FontWeight.w600)),
      const SizedBox(height:3),Text(value,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900,color:_ink)),const SizedBox(height:3),
      Text(trend,style:const TextStyle(fontSize:10,color:_green,fontWeight:FontWeight.w700)),
    ]));
}
class _Legend extends StatelessWidget {
  const _Legend({required this.color,required this.text});final Color color;final String text;
  @override
  Widget build(BuildContext context)=>Row(children:[Container(width:10,height:10,decoration:BoxDecoration(color:color,shape:BoxShape.circle)),const SizedBox(width:8),Text(text,style:const TextStyle(fontSize:12,color:Colors.blueGrey))]);
}
class ExpandedIfWide extends StatelessWidget {
  const ExpandedIfWide({super.key,required this.wide,required this.child});final bool wide;final Widget child;
  @override
  Widget build(BuildContext context)=>wide?Expanded(child:child):SizedBox(width:double.infinity,child:child);
}
