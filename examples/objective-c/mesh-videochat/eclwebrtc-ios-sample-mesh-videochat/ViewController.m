//
//  ViewController.m
//  eclwebrtc-ios-sample-mesh-videochat
//
//

#import "ViewController.h"

//
// Set your APIkey and Domain
//
static NSString *const kAPIkey = @"2142f6af-97df-4c47-a687-fddeca0e3dda";
static NSString *const kDomain = @"localhost";

@interface ViewController () {
    SKWPeer*                        _peer;
    SKWMeshRoom*                    _meshRoom;
    NSString*                       _strOwnId;
    SKWMediaStream*                 _localStream;
    
    // CollectionView for Remote Streams
    RoomCollectionViewController*   _collectionViewController;
}

@property(nonatomic) IBOutlet UILabel*      idLabel;
@property(nonatomic) IBOutlet UITextField*  roomNameField;
@property(nonatomic) IBOutlet SKWVideo*     localView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _idLabel.text = @"N/A";
    _roomNameField.delegate = self;
    
    //
    // Initialize Peer
    //
    SKWPeerOption* options = [[SKWPeerOption alloc] init];
    options.key = kAPIkey;
    options.domain = kDomain;
    _peer = [[SKWPeer alloc] initWithOptions:options];
    
    //
    // Set Peer event callbacks
    //
    
    // OPEN
    [_peer on:SKW_PEER_EVENT_OPEN callback:^(NSObject* obj) {
        
        // Show my ID
        self->_strOwnId = (NSString*)obj;
        self->_idLabel.text = self->_strOwnId;
        
        // Set MediaConstraints
        SKWMediaConstraints* constraints = [[SKWMediaConstraints alloc] init];
        constraints.maxWidth = 960;
        constraints.maxHeight = 540;
        constraints.cameraPosition = SKW_CAMERA_POSITION_FRONT;
        
        // Get a local MediaStream & show it
        [SKWNavigator initialize:self->_peer];
        self->_localStream = [SKWNavigator getUserMedia:constraints];
        [self->_localStream addVideoRenderer:self->_localView track:0];
        
    }];
    
    // CLOSE
    [_peer on:SKW_PEER_EVENT_CLOSE callback:^(NSObject* obj) {
        self->_idLabel.text = @"N/A";
        [SKWNavigator terminate];
        self->_peer = nil;
    }];
    
    [_peer on:SKW_PEER_EVENT_DISCONNECTED callback:^(NSObject* obj) {}];
    [_peer on:SKW_PEER_EVENT_ERROR callback:^(NSObject* obj) {}];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    _localStream = nil;
    _strOwnId = nil;
    _meshRoom = nil;
    _peer = nil;
    _collectionViewController = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

//
// Action for joinButton
//
- (IBAction)onJoinButtonClicked:(id)sender {
    if (nil == _peer || nil != _meshRoom || 0 == _roomNameField.text.length){
        return;
    }
    
    //
    // Join to a MeshRoom
    //
    SKWRoomOption* option = [[SKWRoomOption alloc] init];
    option.mode = SKW_ROOM_MODE_MESH;
    option.stream = _localStream;
    NSString* roomName = [NSString stringWithFormat:@"%@", _roomNameField.text];
    _meshRoom = (SKWMeshRoom*)[_peer joinRoomWithName:roomName options:option];
    
    //
    // Set callbacks for ROOM_EVENTs
    //
    [_meshRoom on:SKW_ROOM_EVENT_OPEN callback:^(NSObject* arg) {
        NSString* roomName = (NSString*)arg;
        NSLog(@"SKW_ROOM_EVENT_OPEN: %@", roomName);
    }];
    [_meshRoom on:SKW_ROOM_EVENT_CLOSE callback:^(NSObject* arg) {
        NSString* roomName = (NSString*)arg;
        NSLog(@"SKW_ROOM_EVENT_CLOSE: %@", roomName);
        [self->_collectionViewController removeAllMediaStreams];
        [self->_meshRoom offAll];
        self->_meshRoom = nil;
    }];
    [_meshRoom on:SKW_ROOM_EVENT_STREAM callback:^(NSObject* arg) {
        SKWMediaStream* stream = (SKWMediaStream*)arg;
        NSLog(@"SKW_ROOM_EVENT_STREAM: %@", stream);
        [self->_collectionViewController addMediaStream:stream];
    }];
    [_meshRoom on:SKW_ROOM_EVENT_PEER_JOIN callback:^(NSObject* arg) {
        NSString* peerId_ = (NSString*)arg;
        NSLog(@"SKW_ROOM_EVENT_PEER_JOIN: %@", peerId_);
    }];
    [_meshRoom on:SKW_ROOM_EVENT_PEER_LEAVE callback:^(NSObject* arg) {
        NSString* peerId_ = (NSString*)arg;
        NSLog(@"SKW_ROOM_EVENT_PEER_LEAVE: %@", peerId_);
        [self->_collectionViewController removePeerStreams:peerId_];
    }];
}

//
// Action for leaveButton
//
- (IBAction)onLeaveButtonClicked:(id)sender {
    if (nil == _peer || nil == _meshRoom){
        return;
    }
    [_meshRoom close];
}


//
// Action for switchCameraButton
//
- (IBAction)onSwitchCameraButtonClicked:(id)sender {
    if(nil == _localStream) {
        return;
    }
    
    SKWCameraPositionEnum pos = [_localStream getCameraPosition];
    if(SKW_CAMERA_POSITION_BACK == pos) {
        pos = SKW_CAMERA_POSITION_FRONT;
    }
    else if(SKW_CAMERA_POSITION_FRONT == pos) {
        pos = SKW_CAMERA_POSITION_BACK;
    }
    else {
        return;
    }
    
    [_localStream setCameraPosition:pos];
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    NSString * segueName = segue.identifier;
    if ([segueName isEqualToString:@"mesh_room_collection"]) {
        _collectionViewController = [segue destinationViewController];
    }
}

@end
