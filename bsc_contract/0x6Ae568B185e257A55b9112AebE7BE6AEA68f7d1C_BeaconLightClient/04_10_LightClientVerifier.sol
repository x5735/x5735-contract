// SPDX-License-Identifier: AML
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.

// 2019 OKIMS

pragma solidity ^0.8.0;

library Pairing {

    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    /*
     * @return The negation of p, i.e. p.plus(p.negate()) should be zero.
     */
    function negate(G1Point memory p) internal pure returns (G1Point memory) {

        // The prime q in the base field F_q for G1
        if (p.X == 0 && p.Y == 0) {
            return G1Point(0, 0);
        } else {
            return G1Point(p.X, PRIME_Q - (p.Y % PRIME_Q));
        }
    }

    /*
     * @return The sum of two points of G1
     */
    function plus(
        G1Point memory p1,
        G1Point memory p2
    ) internal view returns (G1Point memory r) {

        uint256[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
        // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }

        require(success,"pairing-add-failed");
    }

    /*
     * @return The product of a point on G1 and a scalar, i.e.
     *         p == p.scalar_mul(1) and p.plus(p) == p.scalar_mul(2) for all
     *         points p.
     */
    function scalar_mul(G1Point memory p, uint256 s) internal view returns (G1Point memory r) {

        uint256[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
        // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }

    /* @return The result of computing the pairing check
     *         e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
     *         For example,
     *         pairing([P1(), P1().negate()], [P2(), P2()]) should return true.
     */
    function pairing(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2,
        G1Point memory c1,
        G2Point memory c2,
        G1Point memory d1,
        G2Point memory d2
    ) internal view returns (bool) {

        G1Point[4] memory p1 = [a1, b1, c1, d1];
        G2Point[4] memory p2 = [a2, b2, c2, d2];
        uint256 inputSize = 24;
        uint256[] memory input = new uint256[](inputSize);

        for (uint256 i = 0; i < 4; i++) {
            uint256 j = i * 6;
            input[j + 0] = p1[i].X;
            input[j + 1] = p1[i].Y;
            input[j + 2] = p2[i].X[0];
            input[j + 3] = p2[i].X[1];
            input[j + 4] = p2[i].Y[0];
            input[j + 5] = p2[i].Y[1];
        }

        uint256[1] memory out;
        bool success;

        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
        // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }

        require(success,"pairing-opcode-failed");

        return out[0] != 0;
    }
}

contract LightClientVerifier {

    using Pairing for *;

    uint256 constant SNARK_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant PRIME_Q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[32] IC;
    }

    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }

    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(uint256(12136067877651207517560692428929061251727030439667088063356004262286813462364), uint256(9152395427201470744837421906441307306280289252003021742300681400823175737905));
        vk.beta2 = Pairing.G2Point([uint256(2807151715644014126603406928922499966871041507063689855767645663383202439718), uint256(16988940781736750332422892111905643355484089732291907484063479730202364673277)], [uint256(261198546057439780833005544945143550638738857046930311784060721018904941475), uint256(9301213547161341192100742767448214346655947529033841191280835787664434021581)]);
        vk.gamma2 = Pairing.G2Point([uint256(444592058338888741843295796580424895506150225113821898091691605939407182624), uint256(7929729796787020277934304335368755255208423867770381662393873763828078079171)], [uint256(14941053955169893989079753741445597751405967117556041794173597639164058124455), uint256(1138577613276899210214656462923814199343937516733654303128686339349182038886)]);
        vk.delta2 = Pairing.G2Point([uint256(21167274731262625073086770224547997705619642850178397081279756427722858363631), uint256(2935353078344175373919666649280264649406646872318804516518245282068617035795)], [uint256(850488230025003934006252948515698741259933311756700739916718839581764996454), uint256(1696519814340372977005901803551677347316064463369850798505700874551940833315)]);
        vk.IC[0] = Pairing.G1Point(uint256(2761359277744332180183494326299792502176823477325665742706255669644038316344), uint256(18670815533197051371570665056042526590161694615327494841304912314623827586715));
        vk.IC[1] = Pairing.G1Point(uint256(4926163066126633728747080065109889190959522632749409835626345663557746060827), uint256(17973114295206320424480100468740560193003151176929532085777363654873237275740));
        vk.IC[2] = Pairing.G1Point(uint256(15425347981356759845243448152568840562270839807895114752008405600465513888178), uint256(16530136376400072504139112907773400237781268554004188113453529540713498728720));
        vk.IC[3] = Pairing.G1Point(uint256(5106095898879375215620409098327368893062203373010983692284900916693257920124), uint256(20966109731330126367160820773064654441344975400776067163265735000223413265410));
        vk.IC[4] = Pairing.G1Point(uint256(18404282631597833545559259545546319303837121014372065431537587805715287074810), uint256(10846045653727501188920868894778180086341254165614679489592978439728585411139));
        vk.IC[5] = Pairing.G1Point(uint256(8994755490460014264171593573485250730776484335786872952367346889187782226548), uint256(12310416004964677207953179313550743959500578333909345282356293739506943471475));
        vk.IC[6] = Pairing.G1Point(uint256(20460923777455473985462922027555533336335235163029295591227344579312360712648), uint256(14991060387230992072599794432985891567558454809504371386058854043137417396893));
        vk.IC[7] = Pairing.G1Point(uint256(9783501522881628522255582213200563538358516981067477228490003533151024612625), uint256(9003569929021053129210607804002017827052275555172361563798088508421817233979));
        vk.IC[8] = Pairing.G1Point(uint256(20532847807243475885151757309588180536527214079968013445611084540667817722983), uint256(10860522171497487980915749253055510977565545583805069257785699060062340783257));
        vk.IC[9] = Pairing.G1Point(uint256(6549527167959123415815091432908538892665395578827798828751252191511843530253), uint256(11204803492851083443236356318482517701097611867695436027192927198566393299939));
        vk.IC[10] = Pairing.G1Point(uint256(176371034152518309602054350757537222159482433069457972127942611088942751750), uint256(8048213597353429199782881844053706329313427400355877245834047681420128331942));
        vk.IC[11] = Pairing.G1Point(uint256(8148162694007774219944981198684560984856591980346524369332893153919340871442), uint256(9388998466536736294896189348777088759752736187572531110576656245164212284416));
        vk.IC[12] = Pairing.G1Point(uint256(17058512488113992946780509543955888305698655491807274800278954586725524988120), uint256(21021843327851772172927520314916586499058971259265848570888547791015649668109));
        vk.IC[13] = Pairing.G1Point(uint256(5239544579925943427793301801182103535102204512951083138880133530735547386627), uint256(19032391042631013949263414286890864159053318214251976688629488673272870767480));
        vk.IC[14] = Pairing.G1Point(uint256(10514878784208731976225237547153250361055470593826044255883835849726303614222), uint256(9154796104015155470267361332386150392098132416220118182488630708791988510994));
        vk.IC[15] = Pairing.G1Point(uint256(5656143925201060128927531292652589841865636439792530809977211589912455523299), uint256(17963769103616873259155670756780183983599509370811177819767852056518133420087));
        vk.IC[16] = Pairing.G1Point(uint256(18287756749551135501802732396145760864951173089832471956132102601465147953879), uint256(4313459855794286841764363967095687680302603333143831684195674038564338936575));
        vk.IC[17] = Pairing.G1Point(uint256(11852387825752536055006913236755757273324565433087838782506360830661591694793), uint256(3267728197930949676843038406825714779031388613526935036123559101282179797494));
        vk.IC[18] = Pairing.G1Point(uint256(19911781750312815074116011967928005574063484537810784659803298946764878965438), uint256(9237142560299522639335078983243848921244273793807111739544552000611279244293));
        vk.IC[19] = Pairing.G1Point(uint256(20067438311972094495871568406731607810122897312052080846841171437866278576014), uint256(7188106576414909859968265244481161413004528499341197744479506985575242148982));
        vk.IC[20] = Pairing.G1Point(uint256(5160039430689621681158338839425712921878203318176424301569546429535037834608), uint256(2707859762058630411406377778295751061912419469753307739083318799866294757441));
        vk.IC[21] = Pairing.G1Point(uint256(14660538248676455432997650171050324472414463607779952970515682987127396335829), uint256(10364726129441198657067276076223678797713735492899181520795845008448020250046));
        vk.IC[22] = Pairing.G1Point(uint256(14671470602756472601929044361733318623315079978143535379393542725925154421567), uint256(3912940355392174722450370077108637115435853092880247067373965898530498347399));
        vk.IC[23] = Pairing.G1Point(uint256(7131293111651333617082995772956843209408347371744340228640476170425764408040), uint256(15999824188826889997002122285120194719456651439519640745535206007372201632068));
        vk.IC[24] = Pairing.G1Point(uint256(12004717484178870065125617469513022817308824132176022156380136295141235786003), uint256(21376710971398415252509858520182983449989667137707141085039107298383420001607));
        vk.IC[25] = Pairing.G1Point(uint256(4856803391611152164221185989760258450640575200077203806738634282740267778623), uint256(87910675755079400640414496473391743232976607934355281771145783486639300455));
        vk.IC[26] = Pairing.G1Point(uint256(1965786569612591618836077870155558485512770947564895614955799428122679791845), uint256(8878140346071964323715975217452045946083100224403022752233562124818843382062));
        vk.IC[27] = Pairing.G1Point(uint256(378253791266448693824253143648575106654868322397238161589100716468335935055), uint256(14355443344973156811149431998657571038981224057918990468298444409723473409307));
        vk.IC[28] = Pairing.G1Point(uint256(8235725890245262242027778983518722884243665600204823878516495353711441122036), uint256(12130359003544918668986474058128145445774026039283634268976043901656347746034));
        vk.IC[29] = Pairing.G1Point(uint256(15482465721615720526519192675969821885947104754768320137906880946784886167235), uint256(1000866373291893850563905990958428640363670443204976791085124334812287367861));
        vk.IC[30] = Pairing.G1Point(uint256(21855987954476919238218998809740905274416570116861871350265189116242507745211), uint256(9430772068032460333039840146358890154183520562244118275892745905935531123998));
        vk.IC[31] = Pairing.G1Point(uint256(4341312120477270125089706043797599623735338569134277482137051424850911385053), uint256(2459628029830933476052102451579028040930434398429040675058465520567030420983));
    }

    /*
     * @returns Whether the proof is valid given the hardcoded verifying key
     *          above and the public inputs
     */
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[31] memory input
    ) public view returns (bool r) {

        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);

        VerifyingKey memory vk = verifyingKey();

        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);

        // Make sure that proof.A, B, and C are each less than the prime q
        require(proof.A.X < PRIME_Q, "verifier-aX-gte-prime-q");
        require(proof.A.Y < PRIME_Q, "verifier-aY-gte-prime-q");

        require(proof.B.X[0] < PRIME_Q, "verifier-bX0-gte-prime-q");
        require(proof.B.Y[0] < PRIME_Q, "verifier-bY0-gte-prime-q");

        require(proof.B.X[1] < PRIME_Q, "verifier-bX1-gte-prime-q");
        require(proof.B.Y[1] < PRIME_Q, "verifier-bY1-gte-prime-q");

        require(proof.C.X < PRIME_Q, "verifier-cX-gte-prime-q");
        require(proof.C.Y < PRIME_Q, "verifier-cY-gte-prime-q");

        // Make sure that every input is less than the snark scalar field
        for (uint256 i = 0; i < input.length; i++) {
            require(input[i] < SNARK_SCALAR_FIELD,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.plus(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }

        vk_x = Pairing.plus(vk_x, vk.IC[0]);

        return Pairing.pairing(
            Pairing.negate(proof.A),
            proof.B,
            vk.alfa1,
            vk.beta2,
            vk_x,
            vk.gamma2,
            proof.C,
            vk.delta2
        );
    }
}