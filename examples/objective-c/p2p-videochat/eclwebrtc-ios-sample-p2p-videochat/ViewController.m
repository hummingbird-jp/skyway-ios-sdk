//
//  ViewController.m
//  eclwebrtc-ios-sample-p2p-videochat
//
//

#import "ViewController.h"

//
// Set your APIkey and Domain
//
static NSString *const kAPIkey = @"2142f6af-97df-4c47-a687-fddeca0e3dda";
static NSString *const kDomain = @"localhost";

@interface ViewController () {
    SKWPeer*			_peer;
    SKWMediaStream*		_localStream;
    SKWMediaStream*		_remoteStream;
    SKWMediaConnection*	_mediaConnection;
    
    NSString*			_strOwnId;
    BOOL				_bConnected;
    
}

@property (weak, nonatomic) IBOutlet UILabel*   idLabel;
@property (weak, nonatomic) IBOutlet UIButton*  actionButton;
@property (weak, nonatomic) IBOutlet SKWVideo*  localView;
@property (weak, nonatomic) IBOutlet SKWVideo*  remoteView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //
    // Initialize Peer
    //
    SKWPeerOption* option = [[SKWPeerOption alloc] init];
    option.key = kAPIkey;
    option.domain = kDomain;
    _peer	= [[SKWPeer alloc] initWithId:nil options:option];
    
    //
    // Set Peer event callbacks
    //
    
    // OPEN
    [_peer on:SKW_PEER_EVENT_OPEN callback:^(NSObject* obj) {
        
        // Show my ID
        _strOwnId = (NSString*) obj;
        _idLabel.text = _strOwnId;
        
        // Set MediaConstraints
        SKWMediaConstraints* constraints = [[SKWMediaConstraints alloc] init];
        constraints.maxWidth = 960;
        constraints.maxHeight = 540;
        constraints.cameraPosition = SKW_CAMERA_POSITION_FRONT;
        
        // Get a local MediaStream & show it
        [SKWNavigator initialize:_peer];
        _localStream = [SKWNavigator getUserMedia:constraints];
        [_localStream addVideoRenderer:_localView track:0];
        
    }];
    
    // CALL (Incoming call)
    [_peer on:SKW_PEER_EVENT_CALL callback:^(NSObject* obj) {
        if (YES == [obj isKindOfClass:[SKWMediaConnection class]]) {
            _mediaConnection = (SKWMediaConnection *)obj;
            [self setMediaCallbacks];
            [_mediaConnection answer:_localStream];
        }
    }];
    
    [_peer on:SKW_PEER_EVENT_CLOSE callback:^(NSObject* obj) {}];
    [_peer on:SKW_PEER_EVENT_DISCONNECTED callback:^(NSObject* obj) {}];
    [_peer on:SKW_PEER_EVENT_ERROR callback:^(NSObject* obj) {}];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [self updateActionButtonTitle];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    _localStream = nil;
    _remoteStream = nil;
    _strOwnId = nil;
    _mediaConnection = nil;
    _peer = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

//
// Set callbacks for MEDIACONNECTION_EVENTs
//
- (void)setMediaCallbacks {
    if (nil == _mediaConnection) {
        return;
    }

    [_mediaConnection on:SKW_MEDIACONNECTION_EVENT_STREAM callback:^(NSObject* obj) {
         if (YES == [obj isKindOfClass:[SKWMediaStream class]]) {
             if (YES == _bConnected) {
                 return;
             }
             
             // Change connection state
             _bConnected = YES;
             [self updateActionButtonTitle];
             
             // Get a remote MediaStream & show it
             _remoteStream = (SKWMediaStream *)obj;
             dispatch_async(dispatch_get_main_queue(), ^{
                 [_remoteStream addVideoRenderer:_remoteView track:0];
             });
             
         }
     }];
    
    [_mediaConnection on:SKW_MEDIACONNECTION_EVENT_CLOSE callback:^(NSObject* obj) {
        if (NO == _bConnected) {
            return;
        }

        [self closeRemoteStream];
        [self unsetMediaCallbacks];
        _mediaConnection = nil;
        
        _bConnected = NO;
        [self updateActionButtonTitle];

     }];
    
    [_mediaConnection on:SKW_MEDIACONNECTION_EVENT_ERROR callback:^(NSObject* obj) { }];
}

//
// Unset callbacks for PEER_EVENTs
//
- (void)unsetPeerCallbacks {
    if (nil == _peer) {
        return;
    }
    
    [_peer on:SKW_PEER_EVENT_OPEN callback:nil];
    [_peer on:SKW_PEER_EVENT_CONNECTION callback:nil];
    [_peer on:SKW_PEER_EVENT_CALL callback:nil];
    [_peer on:SKW_PEER_EVENT_CLOSE callback:nil];
    [_peer on:SKW_PEER_EVENT_DISCONNECTED callback:nil];
    [_peer on:SKW_PEER_EVENT_ERROR callback:nil];
}

//
// Unset callbacks for MEDIACONNECTION_EVENTs
//
- (void)unsetMediaCallbacks {
    if(nil == _mediaConnection) {
        return;
    }
    
    [_mediaConnection on:SKW_MEDIACONNECTION_EVENT_STREAM callback:nil];
    [_mediaConnection on:SKW_MEDIACONNECTION_EVENT_CLOSE callback:nil];
    [_mediaConnection on:SKW_MEDIACONNECTION_EVENT_ERROR callback:nil];
}

//
// Close & release a remote MediaStream
//
- (void) closeRemoteStream {
    if(nil == _remoteStream) {
        return;
    }
    
    if(nil != _remoteView) {
        [_remoteStream removeVideoRenderer:_remoteView track:0];
    }
    
//    [_remoteStream close:YES];
    _remoteStream = nil;
}

//
// Create a MediaConnection
//
- (void) didSelectPeer:(NSString *)peerId {
    _mediaConnection = [_peer callWithId:peerId stream:_localStream];
    [self setMediaCallbacks];
}

//
// Action for actionButton (make/hang up a call)
//
- (IBAction)onActionButtonClicked:(id)sender {
    
    if(nil == _mediaConnection) {
        
        //
        // Select remote peer & make a call
        //
        
        // Get all IDs connected to the server
        [_peer listAllPeers:^(NSArray* aryPeers){
            NSMutableArray* maItems = [[NSMutableArray alloc] init];
            if (nil == _strOwnId) {
                 return;
            }
            
            // Exclude my own ID
            for (NSString* strValue in aryPeers) {
                if (NSOrderedSame != [_strOwnId caseInsensitiveCompare:strValue]) {
                    [maItems addObject:strValue];
                }
            }
            
            // Show IDs using UITableViewController
            PeerListViewController* vc = [[PeerListViewController alloc] initWithStyle:UITableViewStylePlain];
            vc.items = [NSArray arrayWithArray:maItems];
            vc.delegate = self;
            
            UINavigationController* nc = [[UINavigationController alloc] initWithRootViewController:vc];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentViewController:nc animated:YES completion:nil];
            });
            
            [maItems removeAllObjects];
        
        }];
    }
         
    else {
        
        //
        // hang up a call
        //
        
        [self closeRemoteStream];
        [_mediaConnection close];
    }
}

//
// Update actionButton title
//
- (void)updateActionButtonTitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString* title = (_bConnected) ? @"Hang up" : @"Make Call";
        [_actionButton setTitle:title forState:UIControlStateNormal];
    });
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

//
// Action for muteButton
//
- (IBAction)onAudioMuteButtonClicked:(id)sender {
    if(nil == _localStream) {
        return;
    }

    [_localStream setEnableAudioTrack:0 enable:false];
}

//
// Action for unmuteButton
//
- (IBAction)onAudioUnmuteButtonClicked:(id)sender {
    if(nil == _localStream) {
        return;
    }

    [_localStream setEnableAudioTrack:0 enable:true];
}

@end
